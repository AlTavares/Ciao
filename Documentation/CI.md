# GitHub Actions

CI validates pushes to master, pull requests, and manual runs. It tests the macOS package with complete Swift concurrency checking and warnings as errors, builds the iOS/tvOS library, and builds the iOS/macOS sample. Bonjour tests are separate and opt-in for manual runs; releases require both validation and Bonjour tests at the exact tagged commit.

Both macOS jobs use GitHub's hosted ARM64 `xcode-27` image and select Xcode 27.0 through `DEVELOPER_DIR=/Applications/Xcode_27.0.app/Contents/Developer`. No self-hosted runner registration or local machine is required. The image is currently a public preview; installed versions are documented in [GitHub's runner image inventory](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md).

The sample builds directly from `Sample/CiaoSample.swiftpm/Package.swift` using Xcode's app-playground support. XcodeGen is not required. The sample's Mac destination is Mac Catalyst; native macOS library coverage comes from package tests. The release job uses GitHub's `ubuntu-latest` runner and its GitHub CLI.

Fork PRs can now use hosted runners subject to GitHub's normal workflow approval rules. CI uses read-only repository permissions and checkout does not persist credentials. Only the release job can write releases.

Bonjour integration tests remain opt-in for manual runs and required for releases. They publish and discover services on the same hosted Mac; they do not validate cross-device networking or physical-device permissions. Failures on the hosted environment must be investigated rather than silently skipped.

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
