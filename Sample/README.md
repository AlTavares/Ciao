# Ciao samples

Both samples use SwiftUI app playgrounds with a local SwiftPM dependency on Ciao.

- [CiaoSample](CiaoSample.swiftpm): publication, discovery, and resolution.
- [Bonjour Browser](BonjourBrowser.swiftpm): dynamic service discovery and resolution only.

## CiaoSample — publish and browse

Open `CiaoSample.swiftpm` with Xcode 27, select the `CiaoSample` scheme, and run on an iPhone/iPad simulator, signed device, or My Mac (Mac Catalyst). This is a SwiftUI app playground. Its `Package.swift` imports Apple's `AppleProductTypes` to define the application and capabilities; use Xcode or `xcodebuild` for app builds, not plain `swift build`.

The app imports Ciao and its C target through `.package(path: "../..")`. Keep the sample inside the checkout so this relative dependency resolves. An isolated copy of the playground is not self-contained. Opening it in the standalone Swift Playgrounds app has not been validated.

For signed device runs, select your development team in Xcode's package app settings. CI and the local build commands below disable signing. The Mac version uses Catalyst rather than the previous native macOS target; the Ciao library continues to support native macOS.

Run two instances on the same local network. Use matching TCP/UDP demo types. Publish with port zero, browse in the other instance, open a service, resolve independently, change TXT and press Update TXT, then resolve again to see its new data. Stop publication and observe removal. Repeat start/stop; stop browsing clears membership. Cancellation is available for independent resolution and publication startup.

Listener mode binds an available port and rejects connections. External mode only advertises a nonzero port belonging to an independently running server. Names may be automatically renamed unless the option is disabled. TXT lines use key=value; a line without '=' is a flag. An empty editor clears records. Binary incoming TXT values display as hex when they are not UTF-8.

The manifest's `localNetwork` capability supplies the local-network purpose text and declares `_ciao-demo._tcp` and `_ciao-demo._udp`. Incoming/outgoing network capabilities configure the Mac app. Xcode generates the app's property list and entitlements. Other service types are gated on iOS, including Catalyst; add declared types and obtain multicast entitlement approval where required for broad browsing/enumeration. Verify permission behavior on signed physical devices.

Change app settings in `CiaoSample.swiftpm/Package.swift`. There is no XcodeGen specification or generated project to maintain. Xcode's `.swiftpm` workspace/user state is ignored by Git.

Build from the repository root:

```sh
cd Sample/CiaoSample.swiftpm
xcodebuild -scheme CiaoSample -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -scheme CiaoSample -destination 'platform=macOS,variant=Mac Catalyst' build CODE_SIGNING_ALLOWED=NO
```

## Bonjour Browser — discovery only

Open `BonjourBrowser.swiftpm` in Xcode 27 and run the `BonjourBrowser` scheme on My Mac (Mac Catalyst). This separate app playground uses the local Ciao package and has no publisher or listener.

Press **Start browsing** to enumerate advertised service types using DNS-SD, then continuously browse each discovered type. The default domain is `local.`; stop browsing to change it. Search by name or type and open a service to resolve its hostname, port, IP addresses, and TXT data. Binary TXT values fall back to hexadecimal. Refresh restarts enumeration and every browser; Stop clears results and cancels discovery. Closing a details sheet cancels its resolution.

“All services” means currently advertised, reachable Bonjour services in the selected domain. Network isolation, permissions, and devices that do not advertise themselves can limit results. Services on different interfaces are shown separately. Types are discovered dynamically rather than taken from a fixed list, and endpoint resolution occurs only when a row is opened.

On iOS/iPadOS, arbitrary-type Bonjour browsing requires Apple's approved `com.apple.developer.networking.multicast` entitlement and a matching provisioning profile. The checked-in manifest declares the enumeration type and local-network purpose text; it does not grant this restricted entitlement. The iOS build alone does not establish that broad browsing will work on a signed device. See [Apple's local network privacy guidance](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy). Allow local network access when prompted and refresh after permission changes. Known issue: on the development Mac, all-type enumeration returns DNS-SD `-65555` even with Local Network access enabled and an Apple Development signature. The browser sample is not yet validated end to end. Physical iOS discovery also remains unverified.

```sh
cd Sample/BonjourBrowser.swiftpm
xcodebuild -scheme BonjourBrowser -destination 'platform=macOS,variant=Mac Catalyst' build CODE_SIGNING_ALLOWED=NO
xcodebuild -scheme BonjourBrowser -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

GitHub Actions builds both sample playgrounds for iOS and Mac Catalyst.
