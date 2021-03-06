//
//  ContentViewController.swift
//  GithubPulse
//
//  Created by Tadeu Zagallo on 12/28/14.
//  Copyright (c) 2014 Tadeu Zagallo. All rights reserved.
//

import Cocoa
import WebKit

class ContentViewController: NSViewController, NSXMLParserDelegate, WebPolicyDelegate {
  @IBOutlet weak var webView:WebView?
  @IBOutlet weak var lastUpdate:NSTextField?
  
  var regex = try? NSRegularExpression(pattern: "^osx:(\\w+)\\((.*)\\)$", options: NSRegularExpressionOptions.CaseInsensitive)
  var calls: [String: [String] -> Void]
  
  func loadCalls() {
    self.calls = [:]
    self.calls["contributions"] = { (args) in
      Contributions.fetch(args[0]) { (success, commits, streak, today) in
        if success {
          if args.count < 2 || args[1] == "true" {
            NSNotificationCenter.defaultCenter().postNotificationName("check_icon", object: nil, userInfo: ["today": today])
          }
        }
        let _ = self.webView?.stringByEvaluatingJavaScriptFromString("contributions(\"\(args[0])\", \(success), \(today),\(streak),\(commits))")
      }
    }
    
    self.calls["set"] = { (args) in
      let userDefaults = NSUserDefaults.standardUserDefaults()
      userDefaults.setValue(args[1], forKey: args[0])
      userDefaults.synchronize()
      
      if args[0] == "username" {
        NSNotificationCenter.defaultCenter().postNotificationName("check_username", object: self, userInfo: nil)
      }
      
    }
    
    self.calls["get"] = { (args) in
      var value = NSUserDefaults.standardUserDefaults().valueForKey(args[0]) as? String
      
      if value == nil {
        value = ""
      }
      
      let key = args[0].stringByReplacingOccurrencesOfString("'", withString: "\\'", options: [], range: nil)
      let v = value!.stringByReplacingOccurrencesOfString("'", withString: "\\'", options: [], range: nil)
      
      self.webView?.stringByEvaluatingJavaScriptFromString("get('\(key)', '\(v)', \(args[1]))");
    }
    
    self.calls["remove"] = { (args) in
      let userDefaults = NSUserDefaults.standardUserDefaults()
      userDefaults.removeObjectForKey(args[0])
      userDefaults.synchronize()
      
      if args[0] == "username" {
        NSNotificationCenter.defaultCenter().postNotificationName("check_username", object: self, userInfo: nil)
      }
    }
    
    self.calls["check_login"] = { (args) in
      let active = NSBundle.mainBundle().isLoginItem()
      self.webView?.stringByEvaluatingJavaScriptFromString("raw('check_login', \(active))")
    }
    
    self.calls["toggle_login"] = { (args) in
      if NSBundle.mainBundle().isLoginItem() {
        NSBundle.mainBundle().removeFromLoginItems()
      } else {
        NSBundle.mainBundle().addToLoginItems()
      }
    }
    
    self.calls["quit"] = { (args) in
      NSApplication.sharedApplication().terminate(self)
    }
    
    self.calls["update"] = { (args) in
      GithubUpdate.check(true)
    }

    self.calls["open_url"] = { (args) in
      if let checkURL = NSURL(string: args[0]) {
        NSWorkspace.sharedWorkspace().openURL(checkURL)
      }
    }
  }

  required init?(coder: NSCoder) {
    self.calls = [:]
    super.init(coder: coder)
    self.loadCalls()
  }
  
  override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
    self.calls = [:]
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    self.loadCalls()
  }
  
  override func viewDidLoad() {
#if DEBUG
    let url = NSURL(string: "http://0.0.0.0:8080")!
#else
    let indexPath = NSBundle.mainBundle().pathForResource("index", ofType: "html", inDirectory: "front")
    let url = NSURL(fileURLWithPath: indexPath!)
#endif
    let request = NSURLRequest(URL: url)
    
    self.webView?.policyDelegate = self
    self.webView?.drawsBackground = false
    self.webView?.wantsLayer = true
    self.webView?.layer?.cornerRadius = 5
    self.webView?.layer?.masksToBounds = true
    
    self.webView?.mainFrame.loadRequest(request)
    
    super.viewDidLoad()
  }
  
  @IBAction func refresh(sender: AnyObject?) {
    self.webView?.reload(sender)
  }
  
  func webView(webView: WebView!, decidePolicyForNavigationAction actionInformation: [NSObject : AnyObject]!, request: NSURLRequest!, frame: WebFrame!, decisionListener listener: WebPolicyDecisionListener!) {
    let url:String = request.URL!.absoluteString.stringByRemovingPercentEncoding!

    if url.hasPrefix("osx:") {
      let matches = self.regex?.matchesInString(url, options: [], range: NSMakeRange(0, url.characters.count))
      if let match = matches?[0] {
        let fn = (url as NSString).substringWithRange(match.rangeAtIndex(1))
        let args = (url as NSString).substringWithRange(match.rangeAtIndex(2)).componentsSeparatedByString("%%")
        
        #if DEBUG
          print(fn, args)
        #endif
        
        let closure = self.calls[fn]
        closure?(args)
      }
    } else if (url.hasPrefix("log:")) {
#if DEBUG
      print(url)
#endif
    } else {
      listener.use()
    }
  }
}