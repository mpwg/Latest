// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Latest",
    defaultLocalization: "en",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "LatestCore", targets: ["LatestCore"]),
        .executable(name: "LatestVerification", targets: ["LatestVerification"])
    ],
    targets: [
        .target(name: "LatestCore"),
        .executableTarget(name: "LatestVerification", dependencies: ["LatestCore"])
    ],
    swiftLanguageModes: [.v6]
)
