// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Ciao",
    platforms: [.iOS(.v18), .macOS(.v15), .tvOS(.v18)],
    products: [.library(name: "Ciao", targets: ["Ciao"])],
    targets: [
        .target(name: "CiaoDNS"),
        .target(name: "Ciao", dependencies: ["CiaoDNS"]),
        .testTarget(name: "CiaoTests", dependencies: ["Ciao"]),
        .testTarget(name: "CiaoIntegrationTests", dependencies: ["Ciao"])
    ],
    swiftLanguageModes: [.v6]
)
