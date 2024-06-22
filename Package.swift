// swift-tools-version:5.9

//
// This source file is part of the Stanford Spezi open source project
// 
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
// 
// SPDX-License-Identifier: MIT
//

import PackageDescription


let swiftLintPlugin: Target.PluginUsage = .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")

let package = Package(
    name: "SpeziBluetooth",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SpeziBluetoothServices", targets: ["SpeziBluetoothServices"]),
        .library(name: "SpeziBluetooth", targets: ["SpeziBluetooth"])
    ],
    dependencies: [
        .package(url: "https://github.com/StanfordSpezi/SpeziFoundation", from: "1.1.0"),
        .package(url: "https://github.com/StanfordSpezi/Spezi", from: "1.3.0"),
        .package(url: "https://github.com/StanfordSpezi/SpeziNetworking", from: "2.0.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.59.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.4"),
        .package(url: "https://github.com/realm/SwiftLint.git", .upToNextMinor(from: "0.55.1"))
    ],
    targets: [
        .target(
            name: "SpeziBluetooth",
            dependencies: [
                .product(name: "Spezi", package: "Spezi"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "SpeziFoundation", package: "SpeziFoundation"),
                .product(name: "ByteCoding", package: "SpeziNetworking")
            ],
            resources: [
                .process("Resources")
            ],
            plugins: [swiftLintPlugin]
        ),
        .target(
            name: "SpeziBluetoothServices",
            dependencies: [
                .target(name: "SpeziBluetooth"),
                .product(name: "ByteCoding", package: "SpeziNetworking"),
                .product(name: "SpeziNumerics", package: "SpeziNetworking")
            ],
            plugins: [swiftLintPlugin]
        ),
        .executableTarget(
            name: "TestPeripheral",
            dependencies: [
                .target(name: "SpeziBluetooth"),
                .target(name: "SpeziBluetoothServices"),
                .product(name: "ByteCoding", package: "SpeziNetworking")
            ],
            plugins: [swiftLintPlugin]
        ),
        .testTarget(
            name: "BluetoothServicesTests",
            dependencies: [
                .target(name: "SpeziBluetoothServices"),
                .target(name: "SpeziBluetooth"),
                .product(name: "XCTByteCoding", package: "SpeziNetworking"),
                .product(name: "NIO", package: "swift-nio")
            ],
            plugins: [swiftLintPlugin]
        )
    ]
)
