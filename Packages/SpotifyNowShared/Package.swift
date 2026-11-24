// swift-tools-version: 5.9
import PackageDescription

let products: [Product] = [
    .library(name: "SpotifyNowShared", targets: ["SpotifyNowShared"]),
]

let targets: [Target] = [
    .target(name: "SpotifyNowShared"),
    .testTarget(name: "SpotifyNowSharedTests", dependencies: ["SpotifyNowShared"]),
]

// The Mac app requires macOS 14. Linux only builds the logic tests, so the
// platform list depends on the machine compiling this manifest.
#if os(Linux)
let package = Package(
    name: "SpotifyNowShared",
    products: products,
    targets: targets,
    swiftLanguageVersions: [.v5]
)
#else
let package = Package(
    name: "SpotifyNowShared",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets,
    swiftLanguageVersions: [.v5]
)
#endif
