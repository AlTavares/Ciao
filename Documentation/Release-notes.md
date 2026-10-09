# Ciao 4.0.0 — proposed release notes

- Swift 6 concurrency API with Sendable service/TXT values, actor-owned browsers/publications, bounded async resolution, cancellation, and explicit discovery sessions.
- Network.framework browsing/listeners and DNS-SD independent resolution, external-port registration, and service-type enumeration.
- Binary-safe TXT records, flag/empty values, live updates and clearing, per-interface service identity, and typed errors.
- SwiftPM-only distribution; removes CocoaPods/Carthage framework packaging and Travis CI.
- GitHub Actions validates package tests, supported platform builds and SwiftUI samples. Tagged releases also require live Bonjour checks before creating a GitHub Release.
- New SwiftUI app playground for iOS and Mac Catalyst with manifest-based local-network configuration and explicit cleanup. No XcodeGen or checked-in Xcode project is required; the library still supports native macOS.
- Swift Testing unit/lifecycle tests and separate bounded Bonjour integration tests.

Breaking changes: the callback/NetService API is replaced. Minimum requirements are Swift 6.0, iOS/tvOS 18, and macOS 15. See Migration.md for mappings and cancellation requirements. This release has not been tagged or published.
