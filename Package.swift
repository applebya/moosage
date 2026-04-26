// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsage",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "ClaudeUsageCore",
            path: "Sources/ClaudeUsageCore"
        ),
        .executableTarget(
            name: "ClaudeUsageApp",
            dependencies: ["ClaudeUsageCore"],
            path: "Sources/ClaudeUsageApp"
        ),
        .testTarget(
            name: "ClaudeUsageCoreTests",
            dependencies: ["ClaudeUsageCore"],
            path: "Tests/ClaudeUsageCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
