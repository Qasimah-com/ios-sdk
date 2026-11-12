// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QasimhaCheckout",
    platforms: [.iOS(.v14), .macOS(.v11)],
    products: [
        .library(name: "QasimhaCheckout", targets: ["QasimhaCheckout"]),
    ],
    targets: [
        .target(
            name: "QasimhaCheckout",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "QasimhaCheckoutTests",
            dependencies: ["QasimhaCheckout"]
        ),
    ]
)
