// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Latest",
    defaultLocalization: "en",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "LatestCore", targets: ["LatestCore"]),
        .library(name: "LatestProcess", targets: ["LatestProcess"]),
        .library(name: "LatestPlatform", targets: ["LatestPlatform"]),
        .library(name: "LatestContracts", targets: ["LatestContracts"]),
        .library(name: "LatestTrust", targets: ["LatestTrust"]),
        .executable(name: "LatestBroker", targets: ["LatestBroker"]),
        .executable(name: "LatestVerification", targets: ["LatestVerification"])
    ],
    targets: [
        // bootstrap.py verifies the upstream 2.10.0 distribution against its manifest checksum.
        .binaryTarget(name: "Sparkle", path: "Vendor/Sparkle/Sparkle.xcframework"),
        .target(name: "LatestCore"),
        .target(name: "LatestProcess", dependencies: ["LatestCore"]),
        .target(name: "LatestContracts"),
        .executableTarget(name: "LatestBroker", dependencies: ["LatestCore", "LatestContracts", "LatestTrust", "LatestProcess"]),
        .target(name: "LatestTrust", dependencies: ["LatestCore", "LatestContracts"]),
        .target(name: "LatestPlatform", dependencies: ["LatestCore", "LatestProcess", "LatestContracts", "LatestTrust", "Sparkle"]),
        .executableTarget(name: "LatestVerification", dependencies: ["LatestCore", "LatestProcess", "LatestPlatform"])
    ],
    swiftLanguageModes: [.v6]
)
