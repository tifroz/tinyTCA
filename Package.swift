// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "tinyTCA",
    platforms: [.iOS(.v17), .tvOS(.v17), .macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "tinyTCA",
            targets: ["tinyTCA"]),
    ],
    dependencies: [
        // Swift syntax for macro implementation
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),

        // Skip dependencies (commented out for native-only baseline)
        //.package(url: "https://source.skip.tools/skip.git", from: "1.6.17"),
        //.package(url: "https://source.skip.tools/skip-model.git", from: "1.0.0"),
        //.package(url: "https://source.skip.tools/skip-fuse.git", from: "1.0.0"),
    ],
    targets: [
        // Main library target
        .target(
            name: "tinyTCA",
            dependencies: [
                "tinyTCAMacros",
                //.product(name: "SkipFuse", package: "skip-fuse"),
                //.product(name: "SkipModel", package: "skip-model")
            ],
            plugins: [
                //.plugin(name: "skipstone", package: "skip")
            ]
        ),

        // Macro implementation (compiler plugin)
        .macro(
            name: "tinyTCAMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Main test target
        .testTarget(
            name: "tinyTCATests",
            dependencies: ["tinyTCA"]
        ),

        // Macro expansion tests
        .testTarget(
            name: "tinyTCAMacroTests",
            dependencies: [
                "tinyTCAMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
