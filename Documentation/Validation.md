# Validation record — 2026-10-08

Validated locally using Xcode 27.0 (27A266a), Apple Swift 6.4, and macOS/iOS/tvOS 27.0 SDKs. Package minimums are iOS/tvOS 18 and macOS 15. Xcode agent integration tools were not exposed in this session, so checks used reproducible Swift/Xcode command-line tools and native sample UI inspection.

## Results

| Check | Result |
| --- | --- |
| Swift Testing unit/lifecycle suite | 19 tests passed; complete concurrency checking and Swift warnings as errors |
| Live Bonjour suite | 5 tests / 7 parameterized cases passed on macOS, with explicit opt-in and local-network access |
| iOS library | xcodebuild generic device build passed |
| tvOS library | xcodebuild generic device build passed |
| iOS sample | xcodebuild generic device build passed with signing disabled |
| macOS sample | xcodebuild build passed with signing disabled; launched and inspected |
| DocC | xcodebuild docbuild passed |
| Fresh SwiftPM consumer | Independent local package imported Ciao and compiled publication, discovery, standalone resolution, TXT and cleanup examples |
| Workflow/project YAML | Parsed successfully; GitHub-hosted execution not performed |
| Working diff | git diff --check passed |

## Feature parity

| Capability | Evidence |
| --- | --- |
| Validated TCP/UDP and raw type strings | Type normalization/invalid input unit tests; both transports in live publication/discovery/resolution tests |
| Names/domains and Bonjour defaults | Domain normalization unit test; live default-name/domain publication and repeated reuse |
| Discovery/removal/current membership | Fake snapshot ordering/state tests, 300 additions/removals without drops, live removal |
| Automatic resolution and per-service failure | Live resolved discovery; deterministic failure event and late-result suppression |
| Standalone resolution without connecting | DNSServiceResolve/GetAddrInfo implementation; host, port, numeric IPv4/IPv6 and TXT results verified live |
| External-port advertising | TCP/UDP port already bound by an independent NWListener was advertised successfully without another bind |
| Listener/ephemeral port | TCP/UDP listener publication reported nonzero selected ports |
| Publication rename policy | Different SRV ports with same name fail when renaming disabled and select another name when enabled |
| TXT bytes/flags/empty/read/write/clear/update | Binary/flag/text round-trip tests; live listener and external-port updates and clearing |
| Stop/reuse/cancellation | Generation/overlap/stale-success tests, startup/task cancellation, controlled-clock deadlines, live timeout/cancellation and repeated publication |
| Enumeration | Live ServiceTypeSession discovered the registered type |
| Runtime failure ownership | Fake publication failure after startup emits status and clears current publication |

The native macOS sample was used to publish, browse, inspect independently resolved host/port/addresses, update TXT, resolve the new data, stop and observe removal, then publish again on a fresh port and clear the browsing session. Real native screenshots were inspected during this check. The final rebuilt sample includes a fixed-height TXT editor and publication status observation. Temporary publications were stopped after validation.

## Remaining environment checks

Signed physical iOS/tvOS permission and multicast-entitlement behavior, cross-device discovery, and iOS/tvOS runtime checks require supported devices and provisioning. macOS self-discovery and generic platform builds do not establish those results. Broad enumeration was validated on macOS; the default iOS sample gates undeclared types.

GitHub Actions requires a registered ARM64 macOS runner labelled xcode-27 (and bonjour for network tests) with Xcode at the documented path and permission granted. No remote workflow, release tag, push, or publication was performed. Local logs from this run are in /tmp/ciao-unit.log, /tmp/ciao-integration.log, /tmp/ciao-library-ios.log, /tmp/ciao-ios-build.log, /tmp/ciao-tvos-build.log, /tmp/ciao-macos-build.log, /tmp/ciao-docc.log, and /tmp/ciao-consumer.log.
