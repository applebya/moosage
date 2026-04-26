// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Moosage",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "MoosageCore",
            path: "Sources/MoosageCore"
        ),
        .executableTarget(
            name: "MoosageApp",
            dependencies: ["MoosageCore"],
            path: "Sources/MoosageApp"
        ),
        .testTarget(
            name: "MoosageCoreTests",
            dependencies: ["MoosageCore"],
            path: "Tests/MoosageCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
