//
//  StatusMenuController.swift
//  OnomaMenubar
//
//  Created by Matthew Slipper on 12/21/18.
//  Copyright © 2018 Kyokan. All rights reserved.
//

import Cocoa
import ServiceManagement

class StatusMenuController: NSObject {
    @IBOutlet weak var statusMenu: NSMenu!
    
    @IBOutlet weak var startStopMenuItem: NSMenuItem!
    
    @IBOutlet weak var openAtLoginMenuItem: NSMenuItem!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    let helperManager = HelperManager()
    
    private let launcherBundleName = "com.kyokan.OnomaMenubarLauncher"
    
    private var helperIsInstalled: Bool = false
    
    private var daemonIsRunning: Bool = false
    
    override func awakeFromNib() {
        let icon = NSImage(named: "statusIcon")
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.menu = statusMenu
        
        let foundHelper = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == launcherBundleName
        }
        openAtLoginMenuItem.state = foundHelper ? .on : .off
        
        do {
            try HelperAuthorization.authorizationRightsUpdateDatabase()
        } catch {
            NSLog("Authorization update failed: %@", error as NSError)
            return
        }
        
        helperManager.helperStatus { installed in
            NSLog("Helper installation status: %d", installed)
            self.helperIsInstalled = installed
        }
        
        guard let helper = helperManager.helper(nil) else {
            return
        }
        
        helper.daemonStatus { running in
            if running {
                self.startStopMenuItem.title = "Stop"
                self.daemonIsRunning = true
            }
        }
    }
    
    @IBAction func startStopClicked(_ sender: NSMenuItem) {
        do {
            if !helperIsInstalled {
                if try helperManager.helperInstall() {
                    self.helperIsInstalled = true
                } else {
                    NSLog("Failed with unknown error.")
                    return
                }
            }
            
            guard let helper = helperManager.helper(nil) else {
                showDialog(title: "Something went wrong.", message: "We couldn't start up properly. Please try again. If you ask for help, please include the following error code: ERR_HELPER_NOT_FOUND", buttonTitle: "OK", type: .warning)
                return
            }
            
            if daemonIsRunning {
                stopDaemon(helper: helper, completion: { ok in
                    if ok {
                        self.daemonIsRunning = false
                        OperationQueue.main.addOperation {
                            self.startStopMenuItem.title = "Start"
                        }
                    }
                })
            } else {
                startDaemon(helper: helper, completion: { ok in
                    self.daemonIsRunning = true
                    if ok {
                        OperationQueue.main.addOperation {
                            self.startStopMenuItem.title = "Stop"
                        }
                    }
                })
            }
        } catch {
            showDialog(title: "Something went wrong.", message: "We couldn't start up properly. Please try again.  If you ask for help, please include the following error code: ERR_HELPER_INSTALLATION.", buttonTitle: "OK", type: .warning)
            NSLog("Failed to install helper with error: %@", error as NSError)
        }
    }
    
    @IBAction func aboutClicked(_ sender: NSMenuItem) {
        let ctrlr = AboutWindowController()
        ctrlr.showWindow(nil)
    }
    
    @IBAction func openAtLoginClicked(_ sender: NSMenuItem) {
        // use opposite since UI has not updated yet
        let autolaunch = sender.state == .off
        if SMLoginItemSetEnabled(launcherBundleName as CFString, autolaunch) {
            if autolaunch {
                NSLog("Login item enabled.")
                sender.state = .on
            } else {
                NSLog("Login item disabled.")
                sender.state = .off
            }
        } else {
            showDialog(title: "Something went wrong.", message: "We couldn't make the app open at login. If you ask for help, please include the following error code: ERR_LOGIN_ITEM_SET.", buttonTitle: "OK", type: .warning)
        }
    }
    
    @IBAction func quitClicked(_ sender: NSMenuItem) {
        guard let helper = helperManager.helper(nil) else {
            showDialog(title: "Something went wrong.", message: "We couldn't start up properly. Please try again. If you ask for help, please include the following error code: ERR_HELPER_NOT_FOUND_SHUTDOWN", buttonTitle: "OK", type: .warning)
            NSApplication.shared.terminate(self)
            return
        }
        
        stopDaemon(helper: helper, completion: { ok in
            NSApplication.shared.terminate(self)
        })
    }
    
    private func startDaemon(helper: HelperProtocol, completion: @escaping (Bool) -> Void) -> Void {
        NSLog("Starting daemon.")
        let hnsdURL = Bundle.main.url(forAuxiliaryExecutable: "hnsd")!
        let setDNSURL = Bundle.main.url(forResource: "setdns", withExtension: "sh")!
        helper.setURLs(withHNSDURL: hnsdURL, withSetDNSURL: setDNSURL, completion: { ok in
            if !ok {
                self.showDialog(title: "Something went wrong.", message: "We couldn't start up properly. Please try again. If you ask for help, please include the following error code: ERR_SET_EXC_URL.", buttonTitle: "OK", type: .warning)
                return
            }
            
            helper.startDaemon(completion: { ok in
                if !ok {
                    self.showDialog(title: "Something went wrong.", message: "We couldn't start up properly. Please try again. If you ask for help, please include the following error code: ERR_DAEMON_START.", buttonTitle: "OK", type: .warning)
                }
                
                completion(ok)
            })
        })
    }
    
    private func stopDaemon(helper: HelperProtocol, completion: @escaping (Bool) -> Void) {
        helper.stopDaemon { ok in
            if !ok {
                self.showDialog(title: "Something went wrong.", message: "We couldn't shut down gracefully. If you ask for help, please include the following error code: ERR_DAEMON_STOP.", buttonTitle: "OK", type: .warning)
            }
            
            completion(ok)
        }
    }
    
    @discardableResult
    private func showDialog(title: String, message: String, buttonTitle: String, type: NSAlert.Style) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: buttonTitle)
        return alert.runModal() == .alertFirstButtonReturn
    }
}
