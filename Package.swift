// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GrokbotMonitor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Grokbot", targets: ["GrokbotMonitor"])
    ],
    targets: [
        .executableTarget(
            name: "GrokbotMonitor",
            path: "Sources/GrokbotMonitor"
        ),
        .testTarget(
            name: "GrokbotMonitorTests",
            dependencies: ["GrokbotMonitor"],
            path: "Tests/GrokbotMonitorTests"
        )
    ]
)
