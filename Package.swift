// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FITSKit",
    platforms: [
        .iOS("14"),
        .macOS("11")
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "FITSKit",
            targets: ["FITSKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "FITSCore", url: "https://github.com/brampf/fitscore.git", .exact("0.3.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "FITSKit",
            dependencies: [.product(name: "FITSCore", package: "FITSCore")]),
        .testTarget(
            name: "FITSKitTests",
            dependencies: ["FITSKit","FITSCore"],
            resources: [
                .process("Samples")
            ]),
    ]
)
