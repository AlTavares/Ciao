//
//  MDNSBrowser.swift
//  PowerPetDoor
//
//  Created by Josh Billions on 7/13/24.
//

import Foundation

public class CiaoBrowser {
    var netServiceBrowser: NetServiceBrowser
    var delegate: CiaoBrowserDelegate
    
    public var services = Set<NetService>()
    private var discoveryContinuation: AsyncStream<CiaoBrowserEvent>.Continuation?
    
    public var isSearching = false {
        didSet {
            if isSearching,
               let discoveryContinuation {
                discoveryContinuation.yield(.startedSearch)
            } else if !isSearching,
                      let discoveryContinuation {
                discoveryContinuation.yield(.stoppedSearch)
            }
        }
    }
    
    public init() {
        netServiceBrowser = NetServiceBrowser()
        delegate = CiaoBrowserDelegate()
        netServiceBrowser.delegate = delegate
        delegate.browser = self
    }
    
    public func browse(type: ServiceType, domain: String = "") -> AsyncStream<CiaoBrowserEvent> {
        self.browse(type: type.description, domain: domain)
    }
    
    public func browse(type: String, domain: String = "") -> AsyncStream<CiaoBrowserEvent>{
        self.stop()
        return AsyncStream { continuation in
            self.discoveryContinuation = continuation
            self.netServiceBrowser.searchForServices(ofType: type, inDomain: domain)
        }
    }
    
    fileprivate func serviceFound(_ service: NetService) {
        self.services.update(with: service)
        self.discoveryContinuation?.yield(.found(service))
        
        // resolve services if handler is registered
        guard let discoveryContinuation
        else { return }
        
        var resolver: CiaoResolver? = CiaoResolver(service: service)
        resolver?.resolve(withTimeout: 0) { result in
            discoveryContinuation.yield(.resolved(result))
            // retain resolver until resolution
            resolver = nil
        }
    }
    
    fileprivate func serviceRemoved(_ service: NetService) {
        self.services.remove(service)
        self.discoveryContinuation?.yield(.removed(service))
    }
    
    public func stop() {
        self.netServiceBrowser.stop()
        self.discoveryContinuation?.finish()
        self.discoveryContinuation = nil
    }
    
    deinit {
        self.stop()
    }
}

class CiaoBrowserDelegate: NSObject, NetServiceBrowserDelegate {
    weak var browser: CiaoBrowser?
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        Logger.info("Service found", service)
        self.browser?.serviceFound(service)
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
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        Logger.info("Service removed", service)
        self.browser?.serviceRemoved(service)
    }
}
