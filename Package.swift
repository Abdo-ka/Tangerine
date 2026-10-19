// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "Tangerine", platforms: [.macOS(.v14)],
  products: [.executable(name: "Tangerine", targets: ["Tangerine"])],
  targets: [
    .executableTarget(name: "Tangerine", resources: [.process("Assets")]),
    .testTarget(name: "TangerineTests", dependencies: ["Tangerine"], path: "Tests/Swift"),
  ])
