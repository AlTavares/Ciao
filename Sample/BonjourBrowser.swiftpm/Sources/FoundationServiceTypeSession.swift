import Ciao
import Foundation

/// Sample-only alternative to Ciao's DNS-SD service-type enumerator.
/// Foundation delivers delegate callbacks on the main run loop where browsing starts.
@MainActor
final class FoundationServiceTypeSession: NSObject, @preconcurrency NetServiceBrowserDelegate {
  let types: AsyncThrowingStream<ServiceType, Error>
  private let continuation: AsyncThrowingStream<ServiceType, Error>.Continuation
  private let browser = NetServiceBrowser()
  private var seen: Set<ServiceType> = []
  private var stopped = false

  init(domain: String) {
    (types, continuation) = AsyncThrowingStream.makeStream()
    super.init()
    continuation.onTermination = { [weak self] _ in
      Task { @MainActor in self?.stop() }
    }
    browser.delegate = self
    browser.searchForServices(ofType: "_services._dns-sd._udp.", inDomain: domain)
  }

  func stop() {
    guard !stopped else { return }
    stopped = true
    browser.stop()
    browser.delegate = nil
    continuation.finish()
  }

  func netServiceBrowser(
    _ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool
  ) {
    guard !stopped else { return }
    // Meta-query results contain the service label in name and transport in type.
    guard let transport = service.type.split(separator: ".").first,
      let type = try? ServiceType("\(service.name).\(transport)"),
      seen.insert(type).inserted
    else { return }
    continuation.yield(type)
  }

  func netServiceBrowser(
    _ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]
  ) {
    guard !stopped else { return }
    let code = errorDict["NSNetServicesErrorCode"]?.intValue ?? 0
    let domain = errorDict["NSNetServicesErrorDomain"]?.intValue ?? 0
    continuation.finish(
      throwing: CiaoError.network(
        "NetServiceBrowser enumeration failed (code \(code), domain \(domain))."))
    stop()
  }

  func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
    stop()
  }
}
