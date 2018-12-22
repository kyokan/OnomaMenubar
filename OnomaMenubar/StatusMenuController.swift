//
//  StatusMenuController.swift
//  OnomaMenubar
//
//  Created by Matthew Slipper on 12/21/18.
//  Copyright © 2018 Kyokan. All rights reserved.
//

import Cocoa

class StatusMenuController: NSObject {
    @IBOutlet weak var statusMenu: NSMenu!
    
    @IBOutlet weak var startStop: NSMenuItem!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    let helperManager = HelperManager()
    
    @objc dynamic private var helperIsInstalled = false
    private let helperIsInstalledKeyPath: String
    
    override init () {
        self.helperIsInstalledKeyPath = NSStringFromSelector(#selector(getter: self.helperIsInstalled))
        super.init()
    }
    
    override func awakeFromNib() {
        let icon = NSImage(named: "statusIcon")
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.menu = statusMenu
        
        do {
            try HelperAuthorization.authorizationRightsUpdateDatabase()
        } catch {
            NSLog("Authorization update failed: %@", error as NSError)
            return
        }
        
        helperManager.helperStatus { installed in
            NSLog("Helper installation status: %d", installed)
            self.setValue(installed, forKey: self.helperIsInstalledKeyPath)
        }
        
        guard let helper = helperManager.helper(nil) else {
            return
        }
        
        helper.daemonStatus { running in
            if running {
                self.startStop.title = "Stop"
            }
        }
    }
    
    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func startStopClicked(_ sender: NSMenuItem) {
        do {
            if !helperIsInstalled {
                if try helperManager.helperInstall() {
                    self.setValue(true, forKey: self.helperIsInstalledKeyPath)
                } else {
                    NSLog("Failed with unknown error.")
                    return
                }
            }
            
            guard let helper = helperManager.helper(nil) else {
                NSLog("No helper found.")
                return
            }
            
            NSLog("Starting daemon.")
            let url = Bundle.main.url(forAuxiliaryExecutable: "hnsd")
            helper.startDaemon(withUrl: url!, completion: { code in
                OperationQueue.main.addOperation {
                    self.startStop.title = "Stop"
                }
            })
        } catch {
            NSLog("Failed to install helper with error: %@", error as NSError)
        }
    }
    
    @IBAction func aboutClicked(_ sender: NSMenuItem) {
        let ctrlr = AboutWindowController()
        ctrlr.showWindow(nil)
    }
}
