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
        ),
        .library(
            name: "MaskTextFieldSwiftUI",
            targets: ["MaskTextFieldSwiftUI"]
        )
    ],
    targets: [
        .target(
            name: "MaskTextField",
            path: "Sources/MaskTextField"
        ),
        .target(
            name: "MaskTextFieldSwiftUI",
            dependencies: ["MaskTextField"],
            path: "Sources/MaskTextFieldSwiftUI"
        ),
        .testTarget(
            name: "MaskTextFieldTests",
            dependencies: ["MaskTextField"],
            path: "Tests/MaskTextFieldTests"
        )
    ]
)
