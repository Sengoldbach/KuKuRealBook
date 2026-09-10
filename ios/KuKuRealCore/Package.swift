// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KuKuRealCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "KuKuRealCore", targets: ["KuKuRealCore"])
    ],
    targets: [
        .target(name: "KuKuRealCore"),
        .testTarget(
            name: "KuKuRealCoreTests",
            dependencies: ["KuKuRealCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
