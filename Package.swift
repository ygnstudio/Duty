// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Duty",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Duty",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
