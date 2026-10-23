// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LooplineCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "LooplineCore", targets: ["LooplineCore"])
    ],
    targets: [
        .target(
            name: "LooplineCore",
            path: "LooplineApp/Core"
        ),
        .testTarget(
            name: "LooplineCoreTests",
            dependencies: ["LooplineCore"],
            path: "Tests/LooplineCoreTests"
        ),
        .target(
            name: "LooplineMedia",
            dependencies: ["LooplineCore"],
            path: "LooplineApp/Services",
            exclude: ["AudioClockService.swift", "CaptureCoordinator.swift", "PhotoLibraryExporter.swift"]
        ),
        .testTarget(
            name: "LooplineMediaTests",
            dependencies: ["LooplineCore", "LooplineMedia"],
            path: "Tests/LooplineMediaTests"
        )
    ]
)
