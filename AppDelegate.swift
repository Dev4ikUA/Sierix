//
//  AppDelegate.swift
//  Sierix
//
//  Created by Sunflowerr on 07/11/2026.
//  Copyright © 2026 SunflowerrSunflowerr. All rights reserved.
//

import Cocoa

@NSApplicationMain
@objc(AppDelegate)
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
