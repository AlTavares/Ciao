# Ciao modernization plan

Planning baseline: `master` at `53c2186`. Created 2026-10-08.

## Outcome and decisions

Ship a new major version of Ciao with a modern Bonjour backend, Swift concurrency APIs, Swift Package Manager as the sole library distribution method, reliable tests, and a working SwiftUI sample app.

- Confirmed: a new public API is allowed; existing capabilities must be preserved.
- Confirmed: GitHub Actions is the CI/CD platform for validation and releases.
- Preserve library support for iOS, macOS, and tvOS.
- Working deployment assumption: a modern OS baseline. Select and document exact minimum versions against the installed Xcode 27 SDKs before implementation. The user has not yet specified exact minimum versions.
- Use Xcode 27 and its agent integration for project diagnostics, builds, tests, and sample inspection when those tools are exposed to the session. Keep equivalent command-line checks reproducible in CI.
- Use Swift 6 language mode and complete concurrency checking. Choose the minimum Swift tools version based on the APIs actually required.
- Treat this document as the implementation plan. No library changes or tests have been performed as part of planning.

## Feature parity contract

Establish a behavior-to-test checklist before replacing the backend. Preserve the following capabilities even where their public spelling changes:

| Existing capability | Required outcome |
| --- | --- |
| TCP and UDP service types, including raw type strings | Validated service types with an escape hatch for valid types beyond named conveniences |
| Name and domain selection, including empty/default values | Documented normalization and equivalent Bonjour defaults |
| Browse by type and domain | Discovery, removal, search lifecycle, and accessible current services |
| Automatic resolution after discovery | Resolved results and service-specific resolution failures remain available |
| Standalone resolution | Obtain host name, port, addresses, and TXT data without opening a connection |
| Advertise a supplied port | Publish a service whose listener belongs to the caller, without binding that port again |
| Listener-backed publishing and port zero | Preserve existing listen/ephemeral-port behavior; report the actual assigned port |
| Publication options | Map current options, including automatic renaming policy, to explicit new options |
| TXT records | Read, write, clear, and update text records while publishing; retain bytes in the new representation |
| Start, stop, and reuse | Predictable cancellation, release of resources, and fresh state for subsequent operations |
| Service-type enumeration used by the example | Preserve through the appropriate backend and describe platform entitlement requirements |

The old API exposes `NetService`, so inventory the service information callers can read before replacing it with values. Preserving capabilities does not mean keeping arbitrary Foundation delegate mutation as an extension mechanism.

## 1. Establish the toolchain, contract, and backend design

1. Verify the selected Xcode 27 installation, Swift compiler, installed SDKs/runtimes, and available Xcode agent tools.
2. Select exact OS minimums and record the minimum compiler plus supported CI toolchains.
3. Map the public API and sample behavior to the parity table, including publication options and service enumeration.
4. Perform small backend proofs for external-port advertisement, resolution without connecting, TXT updates, and cancellation.
5. Record the final public API and backend responsibilities in a short architecture decision.

Use Network.framework for normal discovery and listener-backed publication. Use a small internal DNS-SD adapter for operations that need it: standalone resolution, registration of externally owned ports, and service-type enumeration. Include address lookup after DNS-SD service resolution when needed to preserve the returned address information.

Apple explicitly recommends DNS-SD for resolving a service without connecting. Consequently, replacing every `NetService` call with a listener or connection would change Ciao's behavior. Consult the installed SDK for newer structured Network APIs before choosing the concrete implementation, while retaining the same operation boundaries.

Completion: every existing capability has a backend mapping and an acceptance check; the deployment matrix and API are decided.

## 2. Define the concurrency API and deterministic test seams

1. Introduce immutable, `Sendable` values for service identity, discovered/resolved services, TXT records, events, and typed errors. Keep text conveniences over byte-preserving TXT storage.
2. Expose discovery through an async sequence and publication/resolution through `async throws` operations and explicit lifetime handles.
3. Define event ordering, service identity across interfaces, repeat-start behavior, and whether a discovery failure ends the sequence. Associate automatic-resolution failures with the affected service.
4. Give each operation one owner for mutable state. Use actor isolation for the public lifecycle and a narrowly confined callback bridge where required by Network/DNS-SD.
5. Keep the library usable outside the main actor. The sample's UI model will own main-actor isolation.
6. Define cancellation for each entry point: cancellation before startup, cancellation during startup, explicit stop, task cancellation, and late callbacks after termination.
7. Provide a scoped session or explicit cancellation contract for early loop exit. A plain `break` from an async loop must not be assumed to cancel the underlying operation automatically.
8. Choose and document stream buffering. Never silently drop service additions/removals in a way that corrupts the consumer's view of membership.
9. Introduce small internal backend interfaces and controllable clocks so lifecycle tests can run without the network or real sleeps.
10. Replace dictionary retroactive `Error` conformance and mutable global logging configuration with owned error types and configurable, concurrency-safe logging.

Completion: API examples compile with Swift 6 checking; deterministic tests cover lifecycle transitions and cancellation through fake backends. No blanket `@unchecked Sendable` annotations to bypass isolation design; any necessary C-resource wrapper must have a documented invariant.

## 3. Implement the new backend and complete parity tests

Implement incrementally, adding tests alongside each operation:

1. DNS-SD resource ownership, callback delivery, teardown, and cancellation.
2. Publication on an externally owned port, TXT changes, and name-conflict policy.
3. Network discovery with stable service identities, removals, and state reporting.
4. Standalone resolution and the browser's automatic-resolution pipeline.
5. Listener-backed publication, ephemeral ports, and enumeration support.
6. Cleanup across stop/restart, overlapping operations, errors, and delayed callbacks.

Retain a migration bridge only while developing the replacement. The final package's public API should expose Ciao values and options rather than `NetService`, `NetService.Options`, or Objective-C dictionaries.

Completion: all parity cases pass; advertising an already-bound external port succeeds; standalone resolution creates no connection; termination completes once and releases backend resources; restarting never exposes stale services.

## 4. Make SwiftPM the sole distribution method

1. Make `Package.swift` the canonical library manifest, with explicit iOS/macOS/tvOS minimums and Swift language settings.
2. Keep one public library product named `Ciao`; add internal targets only where they improve backend ownership or testing.
3. Remove `Ciao.podspec`, CocoaPods and Carthage release steps, `.travis.yml`, obsolete framework archives, and distribution badges/instructions.
4. Remove the standalone library Xcode project and its XcodeGen framework configuration once the sample consumes the local package directly.
5. Retain an Xcode project for the sample application; SPM-only distribution applies to the library and does not prevent an app project.
6. Remove obsolete scripts and packaging files after checking whether they still demonstrate a required capability.
7. Add `.github/workflows/ci.yml` for pull requests and pushes to `master`: package unit tests, Swift 6 concurrency checking, supported-platform builds, and sample builds. Run Bonjour integration tests as a separate job on a runner with the required network access and permissions; support manual execution for device-dependent checks. Retain diagnostic logs and test results on failures.
8. Add `.github/workflows/release.yml`, triggered by version tags, to validate the exact tagged commit and create a GitHub Release with release notes only after the required checks pass. SwiftPM consumers resolve the Git tag directly; no separate package upload is required. Keep historical releases available for existing consumers.
9. Pin a suitable Xcode environment in both workflows. If Xcode 27 is unavailable on hosted runners, document and use an appropriate runner instead of leaving an unusable workflow. Use read-only permissions for CI and grant release-writing permissions only to the release job. Prevent duplicate releases for the same tag and cancel superseded PR validation runs.

Completion: a fresh consumer can add the package using only its repository URL; no release or build step requires CocoaPods or Carthage; all advertised platforms build; GitHub Actions validates PRs and releases only successfully validated tags.

## 5. Build a SwiftUI sample app

Create an iOS and macOS sample that imports Ciao through a local package reference. Keep tvOS library coverage in the build/test matrix.

The app should allow users to:

- Publish a named TCP or UDP service, choose a domain and port, edit TXT records, and stop publication.
- Browse a declared service type, see discovery/removal updates, and inspect resolved host name, port, addresses, and TXT data.
- Resolve a selected service independently and observe errors or cancellation.
- Exercise repeated start/stop without duplicate sessions or stale UI.

Use a small main-actor model, view-owned tasks, and explicit cleanup. Provide correct local-network purpose text, Bonjour declarations, and applicable macOS sandbox entitlements. Include real screenshots/previews after the app works.

Use a declared demonstration service type for the default flow. Arbitrary types and enumeration require additional multicast entitlement support on iOS; retain the capability and document or gate that advanced sample flow appropriately. Do not claim that broad enumeration works on a default signed iOS app.

Completion: the sample builds through its package dependency and demonstrates publish → discover → resolve → TXT update → stop/removal between running instances.

## 6. Finish validation, documentation, and release preparation

Use Swift Testing for package behavior tests and XCTest/XCUITest where app UI automation requires them.

| Test layer | Required coverage |
| --- | --- |
| Unit | Service-type normalization, identity, TXT byte/text round trips, error mapping |
| Deterministic lifecycle | Cancellation at each stage, completion exactly once, stale callbacks, repeated start/stop, resolver ownership, event ordering, buffering behavior |
| Bonjour integration | TCP/UDP publication, externally owned ports, standalone resolution, TXT updates, removal, name conflicts, timeout and cleanup |
| Sample/UI | Core workflow, visible failures, view/task lifecycle, repeated use |
| Platform | macOS tests and iOS/tvOS builds plus runtime checks on available supported destinations |

Give live network tests unique service names, explicit deadlines, reliable teardown, and a controlled execution policy. Isolate them from fast unit tests. Distinguish missing local-network permissions or unavailable infrastructure from code failures; do not mask failures with automatic retries. Use controlled clocks for precise unit-level timeout checks and suite-level time limits as an additional safeguard.

Use Xcode agent diagnostics and test tools during implementation, then validate the same required checks through documented CLI/CI commands. Validate permission-dependent Bonjour behavior on supported devices; simulator builds alone do not prove network feature parity.

Rewrite the README around SwiftPM installation and the new API. Add DocC documentation and a migration guide covering callbacks to async operations, `NetService` to Ciao values, typed errors, new cancellation ownership, publication options, and the new platform minimums.

Completion: the parity table has recorded results, required builds/tests pass, the sample workflow works, installation instructions match the new release, and release notes clearly describe the major-version changes.

## Suggested delivery sequence

1. Toolchain/backend decision, feature contract, and parity test fixtures.
2. Concurrency API, value models, and deterministic lifecycle tests.
3. Backend replacement with integration coverage.
4. SwiftPM-only distribution and GitHub Actions CI/CD.
5. SwiftUI sample and platform permission configuration.
6. Full parity validation, documentation, and major-release preparation.

Tests accompany each implementation step; the last step consolidates cross-platform and end-to-end evidence. Keep each change reviewable and avoid removing the old implementation before its replacements cover the required behavior.

## References

- [Apple: Choosing the right networking API](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api)
- [Apple: Understanding local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
- [Apple: Giving external agents access to Xcode](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode)
- [Apple: Swift Testing](https://developer.apple.com/documentation/testing)
- [Swift: Migrating to Swift 6](https://www.swift.org/migration/documentation/migrationguide/)

## Implementation record — 2026-10-08

The planned modernization is implemented in the working tree. Final decisions are recorded in `Documentation/Architecture.md`; local results and the feature parity checklist are recorded in `Documentation/Validation.md`. The package uses Swift 6.0 tools/language mode, iOS/tvOS 18 and macOS 15 minimums, with Xcode 27.0 / Swift 6.4 validation. GitHub Actions configuration and runner requirements are in `Documentation/CI.md`. Signed-device permission/cross-device checks and remote CI execution remain environment-dependent. No release was tagged or published.
