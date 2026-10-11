// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EndurancePaywall",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "EndurancePaywall", targets: ["EndurancePaywall"])
    ],
    dependencies: [
        .package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "5.94.0")
    ],
    targets: [
        .target(
            name: "EndurancePaywall",
            dependencies: [
                .product(name: "RevenueCat", package: "purchases-ios"),
                .product(name: "RevenueCatUI", package: "purchases-ios")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "EndurancePaywallTests",
            dependencies: ["EndurancePaywall"]
        )
    ]
)
