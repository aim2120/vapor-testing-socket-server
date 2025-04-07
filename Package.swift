// swift-tools-version: 6.0

import PackageDescription

private let library: Target = .target(
    name: "VaporTestingSocketServer",
    dependencies: [
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "Vapor", package: "vapor"),
        .product(name: "VaporTesting", package: "vapor"),
    ]
)

private let libraryTests: Target = .testTarget(
    name: "\(library.name)Tests",
    dependencies: [.init(stringLiteral: library.name)] + library.dependencies
)

let package = Package(
    name: library.name,
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(name: library.name, targets: [library.name]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0"),
        // documentation
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        library,
        libraryTests,
    ]
)
