// swift-tools-version: 6.0
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "CiaoSample",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .iOSApplication(
            name: "CiaoSample",
            targets: ["App"],
            bundleIdentifier: "com.altavares.ciao.sample",
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [.phone, .pad, .mac],
            supportedInterfaceOrientations: [.portrait, .landscapeLeft, .landscapeRight],
            capabilities: [
                .localNetwork(
                    purposeString: "Ciao discovers and publishes demonstration Bonjour services on your local network.",
                    bonjourServiceTypes: ["_ciao-demo._tcp", "_ciao-demo._udp"]
                ),
                .incomingNetworkConnections(),
                .outgoingNetworkConnections()
            ]
        )
    ],
    dependencies: [.package(path: "../..")],
    targets: [
        .executableTarget(name: "App", dependencies: [.product(name: "Ciao", package: "Ciao")], path: "Sources")
    ],
    swiftLanguageModes: [.v6]
)
