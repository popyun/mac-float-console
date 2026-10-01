// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacConsole",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MacConsole", targets: ["MacConsole"])],
    targets: [.executableTarget(name: "MacConsole")]
)
