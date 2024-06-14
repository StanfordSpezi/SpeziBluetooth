// swift-tools-version:5.9

//
// This source file is part of the Stanford Spezi open source project
// 
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
// 
// SPDX-License-Identifier: MIT
//

import PackageDescription


let package = Package(
    name: "SpeziBluetooth",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BluetoothServices", targets: ["BluetoothServices"]),
        .library(name: "BluetoothViews", targets: ["BluetoothViews"]),
        .library(name: "SpeziBluetooth", targets: ["SpeziBluetooth"])
    ],
    dependencies: [
        .package(url: "https://github.com/StanfordSpezi/SpeziFoundation", branch: "feature/timeout-support"),
        .package(url: "https://github.com/StanfordSpezi/Spezi", from: "1.3.0"),
        .package(url: "https://github.com/StanfordSpezi/SpeziNetworking", from: "2.0.1"),
        .package(url: "https://github.com/StanfordSpezi/SpeziViews", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.59.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.4")
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
            ]
        ),
        .target(
            name: "BluetoothServices",
            dependencies: [
                .target(name: "SpeziBluetooth"),
                .product(name: "ByteCoding", package: "SpeziNetworking"),
                .product(name: "SpeziNumerics", package: "SpeziNetworking")
            ]
        ),
        .target(
            name: "BluetoothViews",
            dependencies: [
                .target(name: "SpeziBluetooth"),
                .product(name: "SpeziViews", package: "SpeziViews")
            ]
        ),
        .executableTarget(
            name: "TestPeripheral",
            dependencies: [
                .target(name: "SpeziBluetooth"),
                .target(name: "BluetoothServices"),
                .product(name: "ByteCoding", package: "SpeziNetworking")
            ]
        ),
        .testTarget(
            name: "BluetoothServicesTests",
            dependencies: [
                .target(name: "BluetoothServices"),
                .target(name: "SpeziBluetooth"),
                .product(name: "XCTByteCoding", package: "SpeziNetworking"),
                .product(name: "NIO", package: "swift-nio")
            ]
        )
    ]
)
