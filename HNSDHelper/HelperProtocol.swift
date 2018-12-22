//
//  HelperProtocol.swift
//  OnomaMenubar
//
//  Created by Matthew Slipper on 12/21/18.
//  Copyright © 2018 Kyokan. All rights reserved.
//

import Foundation

@objc(HelperProtocol)
protocol HelperProtocol {
    func getVersion(completion: @escaping (String) -> Void)
    func daemonStatus(completion: @escaping (Bool) -> Void)
    func startDaemon(withUrl: URL, completion: @escaping (NSNumber) -> Void)
}
