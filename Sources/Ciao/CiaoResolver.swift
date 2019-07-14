//
//  CiaoResolver.swift
//  Ciao
//
//  Created by Alexandre Mantovani Tavares on 14/07/19.
//

import Foundation

public class CiaoResolver {
    public init(service: NetService) {
        self.service = service
    }

    let service: NetService
    let delegate: CiaoResolverDelegate = CiaoResolverDelegate()

    public func resolve(withTimeout timeout: TimeInterval, completion: @escaping (Result<NetService, ErrorDictionary>) -> Void) {
        delegate.onResolve = completion
        service.delegate = delegate
        service.resolve(withTimeout: timeout)
    }

    deinit {
        Logger.verbose(self)
        service.stop()
    }

}

public typealias ErrorDictionary = [String: NSNumber]
extension ErrorDictionary: Error {}

extension CiaoResolver {
    class CiaoResolverDelegate: NSObject, NetServiceDelegate {
        var onResolve: ((Result<NetService, ErrorDictionary>) -> Void)?

        func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
            Logger.error("Service didn't resolve", sender, errorDict)
            onResolve?(Result.failure(errorDict))
        }

        func netServiceDidResolveAddress(_ sender: NetService) {
            Logger.info("Service resolved", sender)
            onResolve?(Result.success(sender))
        }

        func netServiceWillResolve(_ sender: NetService) {
            Logger.info("Service will resolve", sender)
        }
    }
}
