# Migrating to Ciao 4

This is a new major API. Platform minimums become iOS/tvOS 18 and macOS 15; the package uses Swift 6 language mode. Use SwiftPM; CocoaPods/Carthage framework packaging is removed for this version.

| Previous API | New API |
| --- | --- |
| `ServiceType.tcp("http")` | `try ServiceType.tcp("http")`; validated value |
| Raw string overloads | `try ServiceType("_http._tcp.")` |
| `CiaoServer(type:name:port:)` | `CiaoServer()` plus `PublicationConfiguration` |
| `start(options:success:)` | `try await start(configuration)` returns selected name/domain/port |
| `.listenForConnections` | `.listener` mode; binds zero/selected port |
| Advertising an existing nonzero port | `.externalPort` mode |
| `.noAutoRename` | `allowsRenaming: false` |
| `txtRecord = [String: String]?` | `try await updateTXT(TXTRecord(strings: ...))`; `.empty` clears |
| `browser.browse(...)` async stream | `try await browser.browse(...)` returns explicit `DiscoverySession` |
| `NetService` events | Sendable `Service` / `ResolvedService` values |
| Callback resolver | `try await CiaoResolver.resolve(service, timeout: .seconds(10))` |
| `[String: NSNumber]` errors | `CiaoError` with native DNS-SD codes or Network diagnostics |
| Mutable global `LoggerLevel` | Log received errors/events using the application's logger |

Actors require `await` even when reading state. DiscoverySession.services clears on stop. Starting a new browse/publication replaces the previous operation. If a suspended startup is stopped or superseded, it cannot publish a stale success. Cancellation propagates into resource teardown; timeout values must be positive.

A stream has one consumer. Stop its session after an early loop exit; a plain break does not cancel Bonjour. Stop type enumeration explicitly too. Automatic resolution can be disabled with `automaticallyResolve: false`; failed automatic resolution produces `.resolutionFailed(service,error)` and does not end discovery.

Service identities distinguish interfaces. Keep the supplied interface index when resolving a discovered service. Host/port/address/TXT snapshots belong to ResolvedService. Arbitrary mutation of NetService/delegates is no longer a public extension point.

TXTRecord stores flags and Data rather than lossy strings. Keys normalize to lowercase. Invalid UTF-8 remains available as bytes; the text subscript returns nil. Initial listener publication now defaults to an ephemeral port. For an existing application server, explicitly choose external mode; Ciao's own listener rejects connections.

Add local-network purpose text, declared Bonjour types, and required entitlements to the consuming app. The sample includes these defaults. Broad type enumeration on iOS requires multicast entitlement approval.
