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
        resolver = service
        resolverDelegate = CiaoResolver()
        resolverDelegate?.browser = self
        resolver?.delegate = resolverDelegate
        resolver?.resolve(withTimeout: 0.0)
    }

    func resolved(service: NetService) {
        dump(service)
        dump(NetService.dictionary(fromTXTRecord: service.txtRecordData()!).mapValues{String.init(data: $0, encoding: .utf8)!})
    }
}

class CiaoResolver: NSObject, NetServiceDelegate {
    weak var browser: CiaoBrowser?

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        print("did not resolve")
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        print("didResolve")
        browser?.resolved(service: sender)
    }

    func netServiceWillResolve(_ sender: NetService) {
        print("willResolve")
    }
}

class CiaoBrowserDelegate: NSObject, NetServiceBrowserDelegate {
    weak var browser: CiaoBrowser?
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        self.browser?.found(service: service)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
        print(domainString)
    }

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        print("will search")
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("stopped search")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        print("did not search", errorDict)
    }

}
