// swift-tools-version: 6.0

import PackageDescription

let package = Package(

    name: "MDonna",

    platforms: [
        .macOS(.v14)
    ],

    products: [

        .executable(
            name: "MDonna",
            targets: ["MDonna"]
        )
    ],

    targets: [

        .executableTarget(
            name: "MDonna",

            resources: [
                .process("Resources")
            ]
        )
    ]
)
