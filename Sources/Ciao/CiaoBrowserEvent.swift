//
//  File.swift
//  
//
//  Created by Josh Billions on 7/14/24.
//

import Foundation

public enum CiaoBrowserEvent {
    case startedSearch
    case stoppedSearch
    case found(NetService)
    case removed(NetService)
    case resolved(Result<NetService, ErrorDictionary>)
}
