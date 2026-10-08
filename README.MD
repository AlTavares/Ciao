# Ciao

A Swift concurrency library for publishing, discovering, and resolving Bonjour services on iOS, macOS, and tvOS.

The next major version uses Network.framework and DNS-SD, immutable Sendable values, actor-owned lifetimes, and Swift Package Manager. It supports TCP/UDP types, domains, binary TXT records, automatic or standalone resolution, externally owned ports, listener-backed ephemeral ports, and service-type enumeration.

## Requirements and installation

Swift 6.0 or newer; iOS 18, macOS 15, or tvOS 18. Development and CI use Xcode 27.0. This modernization is unreleased; use a local checkout while reviewing it. Once `4.0.0` is released, add:

```swift
.package(url: "https://github.com/AlTavares/Ciao.git", from: "4.0.0")
```

Add `.product(name: "Ciao", package: "Ciao")` to your target dependencies. SwiftPM is the sole distribution method for this major version; older releases remain available.

## Publish

```swift
import Ciao

let server = CiaoServer()
let type = try ServiceType.tcp("ciao-demo")
let info = try await server.start(PublicationConfiguration(
    type: type,
    name: "My service",
    txtRecord: try TXTRecord(strings: ["version": "1"])
))
print(info.service.name, info.port) // listener mode chooses an available port
try await server.updateTXT(TXTRecord(strings: ["version": "2"]))
try await server.updateTXT(.empty) // clear the TXT record
await server.stop()
```

To advertise a server you already run, supply its nonzero port and `mode: .externalPort`. Ciao does not bind that port or open a connection. Set `allowsRenaming: false` to report name conflicts instead of allowing Bonjour to rename. Empty names/domains use Bonjour defaults; publication reports the selected name/domain/port.

Listener mode owns a TCP/UDP listener and rejects incoming connections. Use external mode when your application needs to accept and handle them. Observe `server.events` for publication status and failures after startup. Stopping or cancelling startup releases resources. Starting again replaces the previous publication.

## Browse and resolve

```swift
let browser = CiaoBrowser()
let session = try await browser.browse(type: type) // automatic resolution enabled

do {
    for try await event in session.events {
        switch event {
        case .started: print("Searching")
        case .found(let service): print("Found", service.name)
        case .removed(let service): print("Removed", service.name)
        case .resolved(let result): print(result.hostName, result.port, result.addresses)
        case .resolutionFailed(let service, let error): print(service.name, error)
        case .stopped: print("Stopped")
        }
    }
    await session.stop()
} catch {
    await session.stop()
    throw error
}
```

Always call `session.stop()` after an early `break`. Cancelling stream iteration stops the session; breaking alone does not. Each stream has one consumer and unbounded buffering so membership changes are never dropped. `await session.services` exposes current membership. Service identity includes its network interface; starting a new search clears old membership and cancels old resolvers.

Resolve an independently held service with a bounded operation:

```swift
let service = Service(name: "My service", type: type, domain: "local.")
let result = try await CiaoResolver.resolve(service, timeout: .seconds(10))
```

Resolution queries SRV/TXT and addresses without connecting. The result is a snapshot of the first completed available address batch. `TXTRecord.values` preserves binary bytes, empty values, and flag entries; `record[text: "key"]` is an optional UTF-8 convenience. Discovery failures end the sequence; per-service resolution failures are events. `CiaoError` retains DNS-SD error codes.

## Local-network configuration

Apps must supply `NSLocalNetworkUsageDescription` and declare their Bonjour types in `NSBonjourServices`, for example `_ciao-demo._tcp` and `_ciao-demo._udp`. macOS sandboxed apps need network client/server entitlements for the operations they perform. Local-network permission is granted by the user at runtime.

`ServiceTypeSession` enumerates types through `_services._dns-sd._udp`. Stop it explicitly when finished. Broad enumeration/arbitrary browsing on iOS requires Apple's multicast entitlement approval; the sample defaults to its two declared types and gates other iOS types. Permission-dependent behavior must be checked on signed devices.

## Sample and tests

Open [Sample/CiaoSample.xcodeproj](Sample/CiaoSample.xcodeproj) and choose the iOS or macOS scheme. Run two instances/devices on the same network, publish, browse, inspect resolved details, update TXT, then stop and observe removal. The sample consumes the local package and supports cancellation and repeated use. See [sample instructions](Sample/README.md).

```sh
swift test --skip CiaoIntegrationTests
CIAO_INTEGRATION_TESTS=1 swift test --filter CiaoIntegrationTests
```

Fast Swift Testing tests drive fake backends without the network. Integration tests have unique service names and explicit deadlines; enable them only on a host with local-network permission. GitHub Actions validates the package/platforms/sample and validates tagged commits before releasing. Configure the Xcode 27 runner described in [CI setup](Documentation/CI.md).

Read the [migration guide](Documentation/Migration.md), [architecture decision](Documentation/Architecture.md), and [validation record](Documentation/Validation.md). DocC documentation ships in the package.
