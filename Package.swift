// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "imessage-forwarder",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
    ],
    targets: [
        .executableTarget(
            name: "imessage-forwarder",
            dependencies: [
                .target(name: "App"),
            ]
        ),
        .target(
            name: "App",
            dependencies: [
                .target(name: "Core"),
                .target(name: "WebSocketModule"),
                .target(name: "REST"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .target(
            name: "Core",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .target(
            name: "WebSocketModule",
            dependencies: [
                .target(name: "Core"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .target(
            name: "REST",
            dependencies: [
                .target(name: "Core"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: [
                .target(name: "Core"),
            ]
        ),
    ]
)
