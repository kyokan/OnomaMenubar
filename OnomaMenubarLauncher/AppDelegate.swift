//
//  AppDelegate.swift
//  OnomaMenubarLauncher
//
//  Created by Matthew Slipper on 12/23/18.
//  Copyright © 2018 Kyokan. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains {
            $0.bundleIdentifier == "com.kyokan.OnomaMenubar"
        }
        
        if !isRunning {
            var path = Bundle.main.bundlePath as NSString
            for _ in 1...4 {
                path = path.deletingLastPathComponent as NSString
            }
            NSWorkspace.shared.launchApplication(path as String)
        }
        
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        
    }
}
