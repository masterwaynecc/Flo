// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DawtCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DawtCore", targets: ["DawtCore"])
    ],
    targets: [
        .target(
            name: "DawtCore",
            path: "Sources/DawtCore"
        ),
        .testTarget(
            name: "DawtCoreTests",
            dependencies: ["DawtCore"],
            path: "Tests/DawtCoreTests"
        )
    ]
)
