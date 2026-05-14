   // swift-tools-version: 6.3
   import PackageDescription
   import CompilerPluginSupport

   let package = Package(
       name: "MissingMacros",
       platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
       products: [
           .library(name: "MissingMacros", targets: ["MissingMacros"]),
           .executable(name: "MissingMacrosClient", targets: ["MissingMacrosClient"]),
       ],
       dependencies: [
           .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0-latest"),
       ],
       targets: [
           .macro(
               name: "MissingMacrosInternal",
               dependencies: [
                   .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                   .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
               ]
           ),
           .target(name: "MissingMacros", dependencies: ["MissingMacrosInternal"]),
           .executableTarget(name: "MissingMacrosClient", dependencies: ["MissingMacros"]),
           .testTarget(
               name: "MissingMacrosTests",
               dependencies: [
                   "MissingMacrosInternal",
                   .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
               ]
           ),
       ],
       swiftLanguageModes: [.v6]
   )
