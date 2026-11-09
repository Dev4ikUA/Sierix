//
//  AppDelegate.swift
//  Sierix
//
//  Created by Sunflowerr on 07/11/2026.
//  Copyright © 2026 SunflowerrSunflowerr. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var window: NSWindow!
    var mainViewController: ViewController!
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let windowRect = NSRect(x: 0, y: 0, width: 850, height: 550)
        let styleMask: Int = NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask | NSMiniaturizableWindowMask
        
        window = NSWindow(contentRect: windowRect, styleMask: styleMask, backing: .Buffered, defer: false)
        window.center()
        window.title = "Sierix - Gemini 2.5"
        
        mainViewController = ViewController()
        window.contentViewController = mainViewController
        window.makeKeyAndOrderFront(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool {
        return true
    }
}