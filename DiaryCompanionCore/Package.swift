// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiaryCompanionCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "DiaryCompanionCore", targets: ["DiaryCompanionCore"]),
        .executable(name: "DeepSeekSmoke", targets: ["DeepSeekSmoke"]),
    ],
    targets: [
        .target(name: "DiaryCompanionCore"),
        .executableTarget(
            name: "DeepSeekSmoke",
            dependencies: ["DiaryCompanionCore"]
        ),
        .testTarget(
            name: "DiaryCompanionCoreTests",
            dependencies: ["DiaryCompanionCore"]
        ),
    ]
)
