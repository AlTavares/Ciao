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

    public init() {
        netServiceBrowser = NetServiceBrowser()
        delegate = CiaoBrowserDelegate()
        delegate?.browser = self
        netServiceBrowser.delegate = delegate
    }

    public func browse(type: String, domain: String = "") {
        netServiceBrowser.searchForServices(ofType: "_\(type)._tcp", inDomain: domain)
    }

    func found(service: NetService) {

    }

    private func resolve(service: NetService) {
        resolver = service
        resolverDelegate = CiaoResolver()
        resolverDelegate?.browser = self
        resolver?.delegate = resolverDelegate
        resolver?.resolve(withTimeout: 0.0)
    }

    func resolved(service: NetService) {
        services.insert(service)
        dump(service)
        dump(NetService.dictionary(fromTXTRecord: service.txtRecordData()!).mapValues { String(data: $0, encoding: .utf8)! })
    }
}

class CiaoResolver: NSObject, NetServiceDelegate {
    weak var browser: CiaoBrowser?

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        Logger.verbose("Service didn't resolve", sender)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        browser?.resolved(service: sender)
        Logger.verbose("Service resolved", sender)
    }

    func netServiceWillResolve(_ sender: NetService) {
        Logger.verbose("Service will resolve", sender)
    }
}

class CiaoBrowserDelegate: NSObject, NetServiceBrowserDelegate {
    weak var browser: CiaoBrowser?
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        self.browser?.found(service: service)
        Logger.verbose("Service found")
    }

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        Logger.verbose("Browser will search")
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        Logger.verbose("Browser stopped search")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        Logger.debug("Browser didn't search", errorDict)
    }

}
