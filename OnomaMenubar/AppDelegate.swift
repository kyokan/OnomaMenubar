//
//  AppDelegate.swift
//  OnomaMenubar
//
//  Created by Matthew Slipper on 12/21/18.
//  Copyright © 2018 Kyokan. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains {
            $0.bundleIdentifier == "com.kyokan.OnomaMenubarLauncher"
        }
        
        if isRunning {
            DistributedNotificationCenter.default().postNotificationName(NCConstants.kKillMe, object: Bundle.main.bundleIdentifier, userInfo: nil, options: DistributedNotificationCenter.Options.deliverImmediately)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {}
}
