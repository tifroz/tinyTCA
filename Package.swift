// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "tinyTCA",
    platforms: [.iOS(.v17), .tvOS(.v17), .macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "tinyTCA",
            targets: ["tinyTCA"]),
    ],
    /*dependencies: [
      .package(url: "https://source.skip.tools/skip.git", from: "1.6.17"),
      .package(url: "https://source.skip.tools/skip-model.git", from: "1.0.0"),
      .package(url: "https://source.skip.tools/skip-fuse.git", from: "1.0.0"),
    ],*/
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
          name: "tinyTCA",
          dependencies: [
            //.product(name: "SkipFuse", package: "skip-fuse"),
            //.product(name: "SkipModel", package: "skip-model")
          ],
          plugins: [
            //.plugin(name: "skipstone", package: "skip")
          ],),
        .testTarget(
            name: "tinyTCATests",
            dependencies: ["tinyTCA"]
        ),
    ]
)
