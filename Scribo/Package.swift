// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Scribo",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "Scribo",
            targets: ["Scribo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "0.3.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "10.0.0")
    ],
    targets: [
        .target(
            name: "Scribo",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads")
            ]),
        .testTarget(
            name: "ScriboTests",
            dependencies: ["Scribo"]),
    ]
) 