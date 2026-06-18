// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenCodeStatusBall",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "OpenCodeStatusBall", targets: ["OpenCodeStatusBall"])
    ],
    targets: [
        .executableTarget(
            name: "OpenCodeStatusBall",
            path: "Sources/OpenCodeStatusBall"
        )
    ]
)
