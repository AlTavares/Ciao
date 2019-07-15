//
//  ServiceType.swift
//  Ciao
//
//  Created by Alexandre Tavares on 16/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

import Foundation

public enum ServiceType {
    case tcp(String)
    case udp(String)

    public var description: String {
        switch self {
        case .tcp(let name):
            return "_\(name)._tcp"
        case .udp(let name):
            return "_\(name)._udp"
        }
    }
}
