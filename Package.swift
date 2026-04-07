// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ActivityTracker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ActivityTracker", targets: ["ActivityTracker"])
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0")
    ],
    targets: [
        .executableTarget(
            name: "ActivityTracker",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "ActivityTrackerTests",
            dependencies: ["ActivityTracker"],
            path: "Tests"
        )
    ]
)




