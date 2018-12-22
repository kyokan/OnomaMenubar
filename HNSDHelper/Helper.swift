//
//  Helper.swift
//  OnomaMenubar
//
//  Created by Matthew Slipper on 12/21/18.
//  Copyright © 2018 Kyokan. All rights reserved.
//

import Foundation

class Helper: NSObject, NSXPCListenerDelegate, HelperProtocol {
    private let listener: NSXPCListener
    
    private var connections = [NSXPCConnection]()
    private var shouldQuit = false
    private var shouldQuitCheckInterval = 1.0
    private var isDaemonRunning = false
    private var task: Process?
    
    // MARK: -
    // MARK: Initialization
    
    override init() {
        self.listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
        super.init()
        self.listener.delegate = self
    }
    
    public func run() {
        self.listener.resume()
        
        while !self.shouldQuit {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: self.shouldQuitCheckInterval))
        }
        
        task?.terminate()
    }
    
    // MARK: -
    // MARK: NSXPCListenerDelegate Methods
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard self.isValid(connection: connection) else {
            return false
        }
        
        connection.remoteObjectInterface = NSXPCInterface(with: AppProtocol.self)
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = self
        connection.invalidationHandler = {
            if let connectionIndex = self.connections.firstIndex(of: connection) {
                self.connections.remove(at: connectionIndex)
            }
            
            if self.connections.isEmpty {
                self.shouldQuit = true
            }
        }
        
        self.connections.append(connection)
        connection.resume()
        
        return true
    }
    
    func getVersion(completion: (String) -> Void) {
        completion(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0")
    }
    
    func daemonStatus(completion: (Bool) -> Void) {
        completion(isDaemonRunning)
    }
    
    func startDaemon(withUrl: URL, completion: @escaping (NSNumber) -> Void) {
        if self.isDaemonRunning {
            completion(0)
            return
        }
        
        self.isDaemonRunning = true
        let arguments = ["-p", "4", "-r", "127.0.0.1:53", "-s", "aorsxa4ylaacshipyjkfbvzfkh3jhh4yowtoqdt64nzemqtiw2whk@45.55.108.48"]
        
        task = Process()
        let stdOut = Pipe()
        
        let stdOutHandler =  { (file: FileHandle!) -> Void in
            let data = file.availableData
            guard let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return }
            if let remoteObject = self.connection()?.remoteObjectProxy as? AppProtocol {
                remoteObject.log(stdOut: output as String)
            }
        }
        stdOut.fileHandleForReading.readabilityHandler = stdOutHandler
        
        let stdErr:Pipe = Pipe()
        let stdErrHandler =  { (file: FileHandle!) -> Void in
            let data = file.availableData
            guard let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return }
            if let remoteObject = self.connection()?.remoteObjectProxy as? AppProtocol {
                remoteObject.log(stdErr: output as String)
            }
        }
        stdErr.fileHandleForReading.readabilityHandler = stdErrHandler
        task!.executableURL = withUrl
        task!.arguments = arguments
        task!.standardOutput = stdOut
        task!.standardError = stdErr
        
        task!.terminationHandler = { task in
//            completion(NSNumber(value: task.terminationStatus))
        }
        
        OperationQueue.main.addOperation {
            self.task!.launch()
            completion(0)
        }
    }
    
    private func isValid(connection: NSXPCConnection) -> Bool {
        do {
            return try CodesignCheck.codeSigningMatches(pid: connection.processIdentifier)
        } catch {
            NSLog("Code signing check failed with error: \(error)")
            return false
        }
    }
    
    private func verifyAuthorization(_ authData: NSData?, forCommand command: Selector) -> Bool {
        do {
            try HelperAuthorization.verifyAuthorization(authData, forCommand: command)
        } catch {
            if let remoteObject = self.connection()?.remoteObjectProxy as? AppProtocol {
                remoteObject.log(stdErr: "Authentication Error: \(error)")
            }
            return false
        }
        return true
    }
    
    private func connection() -> NSXPCConnection? {
        return self.connections.last
    }
    
    private func runTaskURL(url: URL, arguments: Array<String>, completion:@escaping ((NSNumber) -> Void)) -> Void {
        
    }
}
