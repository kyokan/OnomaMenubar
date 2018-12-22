//
//  AppProtocol.swift
//  OnomaMenubar
//
//  Created by Matthew Slipper on 12/21/18.
//  Copyright © 2018 Kyokan. All rights reserved.
//

import Foundation

@objc(AppProtocol)
protocol AppProtocol {
    func log(stdOut: String) -> Void
    func log(stdErr: String) -> Void
}
