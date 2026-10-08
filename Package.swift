// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MaskTextField",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "MaskTextField",
            targets: ["MaskTextField"]
        ),
        .library(
            name: "MaskTextFieldSwiftUI",
            targets: ["MaskTextFieldSwiftUI"]
        )
    ],
    targets: [
        .target(
            name: "MaskTextField",
            path: "Sources/MaskTextField",
            resources: [.process("Resources")]
        ),
        .target(
            name: "MaskTextFieldSwiftUI",
            dependencies: ["MaskTextField"],
            path: "Sources/MaskTextFieldSwiftUI"
        ),
        .testTarget(
            name: "MaskTextFieldTests",
            dependencies: ["MaskTextField", "MaskTextFieldSwiftUI"],
            path: "Tests/MaskTextFieldTests"
        )
    ]
)
