// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Latest",
    defaultLocalization: "en",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "LatestCore", targets: ["LatestCore"]),
        .library(name: "LatestApplication", targets: ["LatestApplication"]),
        .library(name: "LatestProcess", targets: ["LatestProcess"]),
        .library(name: "LatestPlatform", targets: ["LatestPlatform"]),
        .library(name: "LatestContracts", targets: ["LatestContracts"]),
        .library(name: "LatestTrust", targets: ["LatestTrust"]),
        .library(name: "Sparkle", targets: ["Sparkle"]),
        .executable(name: "LatestBroker", targets: ["LatestBroker"]),
        .executable(name: "LatestApp", targets: ["LatestApp"]),
        .executable(name: "LatestPackageVerifier", targets: ["LatestPackageVerifier"]),
        .executable(name: "LatestRelease", targets: ["LatestRelease"]),
        .executable(name: "LatestVerification", targets: ["LatestVerification"])
    ],
    targets: [
        // bootstrap.py verifies the upstream 2.10.0 distribution against its manifest checksum.
        .binaryTarget(name: "Sparkle", path: "Vendor/Sparkle/Sparkle.xcframework"),
        .target(name: "LatestCore"),
        .target(name: "LatestApplication", dependencies: ["LatestCore"]),
        .target(name: "LatestProcess", dependencies: ["LatestCore"]),
        .target(name: "LatestContracts"),
        .executableTarget(name: "LatestRelease", dependencies: ["LatestCore"]),
        .executableTarget(name: "LatestPackageVerifier", dependencies: ["LatestCore", "LatestProcess"]),
        .executableTarget(name: "LatestApp", dependencies: ["LatestCore", "LatestApplication", "LatestPlatform", "Sparkle"], exclude: ["Resources"],
                          swiftSettings: [.defaultIsolation(MainActor.self)]),
        .executableTarget(name: "LatestBroker", dependencies: ["LatestCore", "LatestContracts", "LatestTrust", "LatestProcess"]),
        .target(name: "LatestTrust", dependencies: ["LatestCore", "LatestContracts"]),
        .target(name: "LatestPlatform", dependencies: ["LatestApplication", "LatestCore", "LatestProcess", "LatestContracts", "LatestTrust", "Sparkle"]),
        .executableTarget(name: "LatestVerification", dependencies: ["LatestCore", "LatestProcess", "LatestPlatform", "LatestContracts", "LatestTrust"]),
        .testTarget(name: "LatestCoreTests", dependencies: ["LatestCore", "LatestApplication", "LatestPlatform"])
    ],
    swiftLanguageModes: [.v6]
)
