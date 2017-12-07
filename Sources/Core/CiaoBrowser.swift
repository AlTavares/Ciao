//
//  CiaoBrowser.swift
//  Ciao
//
//  Created by Alexandre Tavares on 11/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

import Foundation

public class CiaoBrowser {

    var netServiceBrowser: NetServiceBrowser
    var delegate: CiaoBrowserDelegate?
    var resolver: NetService?
    var resolverDelegate: CiaoResolver?
    public var services = Set<NetService>()
    private var servicesToBeResolved = Set<NetService>()
    private var serviceFoundHandler: ((NetService) -> Void)!
    public var isSearching = false {
        didSet {
            Logger.info(isSearching)
        }
    }

    public init() {
        netServiceBrowser = NetServiceBrowser()
        delegate = CiaoBrowserDelegate()
        delegate?.browser = self
        netServiceBrowser.delegate = delegate
    }

    public func browse(type: ServiceType, domain: String = "", serviceFoundHandler: @escaping (NetService) -> Void) {
        browse(type: type.description, serviceFoundHandler: serviceFoundHandler)
    }

    public func browse(type: String, domain: String = "", serviceFoundHandler: @escaping (NetService) -> Void) {
        if isSearching {
            stop()
        }
        netServiceBrowser.searchForServices(ofType: type, inDomain: domain)
        self.serviceFoundHandler = serviceFoundHandler
    }

    func resolve(service: NetService) {
        guard resolver == nil else { // put in a queue to resolve
            servicesToBeResolved.insert(service)
            return
        }
        resolver = service
        resolverDelegate = CiaoResolver()
        resolverDelegate?.browser = self
        resolver?.delegate = resolverDelegate
        resolver?.resolve(withTimeout: 0.0)
    }

    func resolved(service: NetService) {
        resolver = nil
        services.insert(service)
        serviceFoundHandler(service)
        Logger.debug("Services to be resolved: \(servicesToBeResolved.count)")
        if let serviceToBeResolved = servicesToBeResolved.popFirst() {
            resolve(service: serviceToBeResolved)
        }
    }

    public func stop() {
        netServiceBrowser.stop()
        resolver?.stop()
    }

    deinit {
        stop()
    }
}

class CiaoResolver: NSObject, NetServiceDelegate {
    weak var browser: CiaoBrowser?

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        Logger.error("Service didn't resolve", sender)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        browser?.resolved(service: sender)
        Logger.info("Service resolved", sender)
    }

    func netServiceWillResolve(_ sender: NetService) {
        Logger.info("Service will resolve", sender)
    }

}

class CiaoBrowserDelegate: NSObject, NetServiceBrowserDelegate {
    weak var browser: CiaoBrowser?
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        self.browser?.resolve(service: service)
        Logger.info("Service found")
    }

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        Logger.info("Browser will search")
        self.browser?.isSearching = true
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        Logger.info("Browser stopped search")
        self.browser?.isSearching = false
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        Logger.debug("Browser didn't search", errorDict)
        self.browser?.isSearching = false
    }

}
