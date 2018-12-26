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
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(self.terminate), name: NCConstants.kKillMe, object: "com.kyokan.OnomaMenubar")
            
            let path = Bundle.main.bundlePath as NSString
            var components = path.pathComponents
            components.removeLast(3)
            components.append("MacOS")
            components.append("OnomaMenubar")
            let newPath = NSString.path(withComponents: components)
            NSWorkspace.shared.launchApplication(newPath)
        } else {
            self.terminate()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {}
    
    @objc
    func terminate() {
        NSApp.terminate(nil)
    }
}
