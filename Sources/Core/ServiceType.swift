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

    var description: String {
        switch self {
        case .tcp(let name):
            return "_\(name)._tcp"
        }
    }
}
