//
//  Helper.swift
//  OnomaMenubar
//
//  Created by Matthew Slipper on 12/21/18.
//  Copyright © 2018 Kyokan. All rights reserved.
//

import Foundation

enum STDIOType {
    case StdOut
    case StdErr
}

class Helper: NSObject, NSXPCListenerDelegate, HelperProtocol {
    private let listener: NSXPCListener
    private var connections = [NSXPCConnection]()
    private var shouldQuit = false
    private var shouldQuitCheckInterval = 1.0
    private var task: Process?
    private var hnsdURL: URL?
    private var setDNSURL: URL?
    
    // MARK: -
    // MARK: Initialization
    
    override init() {
        self.listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
        super.init()
        self.listener.delegate = self
    }
    
    public func run() {
        NSLog("starting")
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
        completion(task != nil)
    }
    
    func setURLs(withHNSDURL: URL, withSetDNSURL: URL, completion: @escaping (Bool) -> Void) {
        hnsdURL = withHNSDURL
        setDNSURL = withSetDNSURL
        completion(true)
    }
    
    func startDaemon(completion: @escaping (Bool) -> Void) {
        if self.task != nil {
            completion(true)
            return
        }
        
        let arguments = ["-p", "4", "-r", "127.0.0.1:53", "-s", "aorsxa4ylaacshipyjkfbvzfkh3jhh4yowtoqdt64nzemqtiw2whk@45.55.108.48"]
        
        task = Process()
        let stdOut = Pipe()
        let stdOutHandler =  makeSTDIOHandler(type: STDIOType.StdOut)
        stdOut.fileHandleForReading.readabilityHandler = stdOutHandler
        let stdErr: Pipe = Pipe()
        let stdErrHandler =  makeSTDIOHandler(type: STDIOType.StdErr)
        stdErr.fileHandleForReading.readabilityHandler = stdErrHandler
        task!.executableURL = hnsdURL
        task!.arguments = arguments
        task!.standardOutput = stdOut
        task!.standardError = stdErr
        task!.terminationHandler = { task in
            self.task = nil
        }
        
        OperationQueue.main.addOperation {
            self.task!.launch()
            self.setDNS(servers: ["127.0.0.1"], completion: { code in
                completion(code == 0)
            })
        }
    }
    
    func stopDaemon(completion: @escaping (Bool) -> Void) {
        if task == nil {
            completion(true)
            return
        }
        
        // setting to nil is handled in termination handler above
        task?.terminate()
        setDNS(servers: ["empty"], completion: { code in
            completion(code == 0)
        })
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
    
    private func setDNS(servers: [String], completion: @escaping (NSNumber) -> Void) {
        let setupTask = Process()
        setupTask.executableURL = setDNSURL
        let stdOut = Pipe()
        let stdOutHandler =  makeSTDIOHandler(type: STDIOType.StdOut)
        stdOut.fileHandleForReading.readabilityHandler = stdOutHandler
        let stdErr: Pipe = Pipe()
        let stdErrHandler =  makeSTDIOHandler(type: STDIOType.StdErr)
        stdErr.fileHandleForReading.readabilityHandler = stdErrHandler
        setupTask.standardOutput = stdOut
        setupTask.standardError = stdErr
        setupTask.arguments = servers
        setupTask.terminationHandler = { task in
            completion(NSNumber(value: task.terminationStatus))
        }
        
        OperationQueue.main.addOperation {
            setupTask.launch()
        }
    }
    
    private func makeSTDIOHandler(type: STDIOType) -> (_: FileHandle) -> Void {
        return { (file: FileHandle!) -> Void in
            let data = file.availableData
            guard let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return }
            if let remoteObject = self.connection()?.remoteObjectProxy as? AppProtocol {
                if type == STDIOType.StdOut {
                    remoteObject.log(stdOut: output as String)
                } else {
                    remoteObject.log(stdErr: output as String)
                }
            }
        }
    }
}

