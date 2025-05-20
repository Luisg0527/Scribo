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
        .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "Scribo",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ]),
        .testTarget(
            name: "ScriboTests",
            dependencies: ["Scribo"]),
    ]
) 