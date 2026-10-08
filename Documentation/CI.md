# GitHub Actions

CI validates pushes to master, same-repository pull requests, and manual runs. It tests the macOS package with complete Swift concurrency checking and warnings as errors, builds the iOS/tvOS library, and builds the iOS/macOS sample. Bonjour tests are separate and opt-in for manual runs; releases require both validation and Bonjour tests at the exact tagged commit.

Configure an ARM64 macOS self-hosted runner labelled `xcode-27`, with `/Applications/Xcode-27.0.0.app` installed. Add the `bonjour` label to a runner with local-network access and permission granted to the test process. Runners require Git and Swift/Xcode; the Ubuntu release job requires GitHub CLI (provided by the runner image). The sample builds directly from `Sample/CiaoSample.swiftpm/Package.swift` using Xcode's app-playground support. XcodeGen is not required. The sample's Mac destination is Mac Catalyst; native macOS library coverage comes from package tests.

The workflows explicitly use a self-hosted Xcode 27 environment instead of assuming a hosted image has this SDK. Repository administrators must register this runner before CI can execute. Fork PRs are not automatically executed on this persistent runner: review and bring approved changes to a trusted branch, or run them on a separately provisioned ephemeral runner. CI uses read-only repository permissions and checkout does not persist credentials. Only the release job can write releases.

Create a semantic version tag such as `v4.0.0` after approving release preparation. The release workflow validates the tag commit, then generates GitHub Release notes. Existing releases are detected to prevent duplicates. SwiftPM resolves the Git tag directly; there is no package upload. Historical releases remain available.

Local equivalents:

```sh
swift test --skip CiaoIntegrationTests -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
CIAO_INTEGRATION_TESTS=1 swift test --filter CiaoIntegrationTests
xcodebuild -scheme Ciao -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -scheme Ciao -destination 'generic/platform=tvOS' build CODE_SIGNING_ALLOWED=NO
cd Sample/CiaoSample.swiftpm
xcodebuild -scheme CiaoSample -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -scheme CiaoSample -destination 'platform=macOS,variant=Mac Catalyst' build CODE_SIGNING_ALLOWED=NO
```
