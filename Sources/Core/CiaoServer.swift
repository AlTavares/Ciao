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
    var successCallback: ((Bool) -> Void)?
    public fileprivate(set) var started = false {
        didSet {
            successCallback?(started)
            successCallback = nil
        }
    }
    public var txtRecord: [String: String]? {
        get {
            return netService.txtRecordDictionary
        }
        set {
            netService.setTXTRecord(dictionary: newValue)
            Logger.info("TXT Record updated", newValue as Any)
        }
    }

    public convenience init(type: ServiceType, domain: String = "", name: String = "") {
        self.init(type: type.description, domain: domain, name: name)
    }

    public init(type: String, domain: String = "", name: String = "") {
        netService = NetService(domain: domain, type: type, name: name)
        delegate = CiaoServerDelegate()
        delegate?.server = self
        netService.delegate = delegate
    }

    public func start(success: ((Bool) -> Void)? = nil) {
        if started {
            success?(true)
            return
        }
        successCallback = success
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
    weak var server: CiaoServer?

    func netServiceDidPublish(_ sender: NetService) {
        server?.started = true
        Logger.info("CiaoServer Started")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        server?.started = false
        Logger.error("CiaoServer did not publish", errorDict)
    }

    func netServiceDidStop(_ sender: NetService) {
        server?.started = false
        Logger.info("CiaoServer Stoped")
    }
}
