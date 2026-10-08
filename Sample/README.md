# Ciao sample

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
