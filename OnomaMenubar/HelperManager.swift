//
//  HelperManager.swift
//  OnomaMenubar
//
//  Created by Matthew Slipper on 12/21/18.
//  Copyright © 2018 Kyokan. All rights reserved.
//

import Foundation
import ServiceManagement

class HelperManager: NSObject, AppProtocol {
    private var currentHelperConnection: NSXPCConnection?
    
    func helperConnection() -> NSXPCConnection? {
        guard self.currentHelperConnection == nil else {
            return self.currentHelperConnection
        }
        
        let connection = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
        connection.exportedInterface = NSXPCInterface(with: AppProtocol.self)
        connection.exportedObject = self
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.invalidationHandler = {
            self.currentHelperConnection?.invalidationHandler = nil
            OperationQueue.main.addOperation {
                self.currentHelperConnection = nil
            }
        }
        
        self.currentHelperConnection = connection
        self.currentHelperConnection?.resume()
        return self.currentHelperConnection
    }
    
    func helper(_ completion: ((Bool) -> Void)?) -> HelperProtocol? {
        
        // Get the current helper connection and return the remote object (Helper.swift) as a proxy object to call functions on.
        
        guard let helper = self.helperConnection()?.remoteObjectProxyWithErrorHandler({ error in
            if let onCompletion = completion { onCompletion(false) }
        }) as? HelperProtocol else { return nil }
        return helper
    }
    
    func helperStatus(completion: @escaping (_ installed: Bool) -> Void) {
        var sent = false
        
        func wrappedCompletion (_ realCompletion: Bool) -> Void {
            if sent {
                return
            }
            
            sent = true
            completion(realCompletion)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            wrappedCompletion(false)
        }
        
        // Comppare the CFBundleShortVersionString from the Info.plisin the helper inside our application bundle with the one on disk.
        
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/" + HelperConstants.machServiceName)
        guard
            let helperBundleInfo = CFBundleCopyInfoDictionaryForURL(helperURL as CFURL) as? [String: Any],
            let helperVersion = helperBundleInfo["CFBundleShortVersionString"] as? String,
            let helper = self.helper(completion) else {
                wrappedCompletion(false)
                return
        }
        
        helper.getVersion { installedHelperVersion in
            wrappedCompletion(installedHelperVersion == helperVersion)
        }
    }
    
    func helperInstall() throws -> Bool {
        
        // Install and activate the helper inside our application bundle to disk.
        
        var cfError: Unmanaged<CFError>?
        var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value:UnsafeMutableRawPointer(bitPattern: 0), flags: 0)
        var authRights = AuthorizationRights(count: 1, items: &authItem)
        
        guard
            let authRef = try HelperAuthorization.authorizationRef(&authRights, nil, [.interactionAllowed, .extendRights, .preAuthorize]),
            SMJobBless(kSMDomainSystemLaunchd, HelperConstants.machServiceName as CFString, authRef, &cfError) else {
                if let error = cfError?.takeRetainedValue() { throw error }
                return false
        }
        
        self.currentHelperConnection?.invalidate()
        self.currentHelperConnection = nil
        
        return true
    }
    
    func log(stdOut: String) {
        guard !stdOut.isEmpty else { return }
        OperationQueue.main.addOperation {
           NSLog("[stdin] %@", stdOut)
        }
    }
    
    func log(stdErr: String) {
        guard !stdErr.isEmpty else { return }
        OperationQueue.main.addOperation {
            NSLog("[stdout] %@", stdErr)
        }
    }
}
