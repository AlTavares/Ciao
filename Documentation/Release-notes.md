# Ciao 4 — release notes

- Swift 6 concurrency API with Sendable service/TXT values, actor-owned browsers/publications, bounded async resolution, cancellation, and explicit discovery sessions.
- Network.framework browsing/listeners and DNS-SD independent resolution, external-port registration, and service-type enumeration.
- Binary-safe TXT records, flag/empty values, live updates and clearing, per-interface service identity, and typed errors.
- SwiftPM-only distribution; removes CocoaPods/Carthage framework packaging and Travis CI.
- GitHub Actions validates package tests, supported platform builds and SwiftUI samples. Tagged releases also require live Bonjour checks before creating a GitHub Release.
- SwiftUI publisher/browser and standalone Bonjour Browser app playgrounds for iOS and Mac Catalyst with manifest-based local-network configuration and explicit cleanup. No XcodeGen or checked-in Xcode project is required; the library still supports native macOS.
- Swift Testing unit/lifecycle tests and separate bounded Bonjour integration tests.

Breaking changes: the callback/NetService API is replaced. Minimum requirements are Swift 6.0, iOS/tvOS 18, and macOS 15. See Migration.md for mappings and cancellation requirements. 

## Known limitations

- The new Bonjour Browser sample fails all-service-type enumeration with DNS-SD `-65555` on the development Mac, despite enabled Local Network access and Apple Development signing. This remains unresolved; compilation success does not establish working broad discovery.
- Broad Bonjour browsing on physical iOS devices requires Apple's approved multicast entitlement and matching provisioning. The sample does not provide that entitlement.
- Hosted Bonjour integration checks exercise same-host discovery; cross-device and physical-device permission behavior still require validation.
