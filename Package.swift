// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ComposableGoogleMobileAds",
    platforms: [.iOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ComposableGoogleMobileAds",
            targets: ["ComposableGoogleMobileAds"]),
    ],
    dependencies: [
      .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "11.13.0"),
      .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.16.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ComposableGoogleMobileAds",
            dependencies: [
              .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
              .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
              
            ]),

    ]
)
