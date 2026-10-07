// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MaskTextField",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "MaskTextField",
            targets: ["MaskTextField"]
        )
    ],
    targets: [
        .target(
            name: "MaskTextField",
            path: "Sources/MaskTextField"
        ),
        .testTarget(
            name: "MaskTextFieldTests",
            dependencies: ["MaskTextField"],
            path: "Tests/MaskTextFieldTests"
        )
    ]
)
