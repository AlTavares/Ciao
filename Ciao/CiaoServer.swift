//
//  CiaoService.swift
//  Ciao
//
//  Created by Alexandre Tavares on 10/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

import Foundation

public class CiaoServer {
    var netService: NetService
    var delegate: CiaoServerDelegate?
    public var txtRecord: [String: String]? {
        get {
            guard let data = netService.txtRecordData() else { return nil }
            return NetService.dictionary(fromTXTRecord: data)
        }
        set {
            netService.setTXTRecord(dictionary: newValue)
        }
    }

    public init(type: String, domain: String = "", name: String = "") {
        netService = NetService(domain: domain, type: "_\(type)._tcp", name: name)
        delegate = CiaoServerDelegate()
        netService.delegate = delegate
        netService.schedule(in: RunLoop.current, forMode: RunLoopMode.commonModes)
        netService.publish(options: NetService.Options.listenForConnections)
    }

    public func stop() {
        netService.stop()
    }

    deinit {
        stop()
    }
}

class CiaoServerDelegate: NSObject, NetServiceDelegate {
}
