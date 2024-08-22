// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "i2cSlave",
    products: [
        .library(
            name: "i2cSlave",
            targets: ["i2cSlave"]),
    ],
    dependencies: [
        .package(url: "https://github.com/microswift-packages/i2c", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "i2cSlave",
            dependencies: [],
            path: ".",
            sources: ["i2cSlave.swift"]),
    ]
)
