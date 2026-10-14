// swift-tools-version: 6.0
import AppleProductTypes
import PackageDescription

let package = Package(
  name: "BonjourBrowser",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [
    .iOSApplication(
      name: "BonjourBrowser",
      targets: ["App"],
      bundleIdentifier: "com.altavares.ciao.browser",
      displayVersion: "1.0",
      bundleVersion: "1",
      supportedDeviceFamilies: [.phone, .pad, .mac],
      supportedInterfaceOrientations: [.portrait, .landscapeLeft, .landscapeRight],
      capabilities: [
        .localNetwork(
          purposeString:
            "Browse Bonjour services advertised on your local network.",
          bonjourServiceTypes: ["_services._dns-sd._udp"]
        ),
        .outgoingNetworkConnections(),
      ]
    )
  ],
  dependencies: [.package(path: "../..")],
  targets: [
    .executableTarget(
      name: "App", dependencies: [.product(name: "Ciao", package: "Ciao")], path: "Sources")
  ],
  swiftLanguageModes: [.v6]
)
