// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "baobao",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        // 将executable改为library
        .library(
            name: "BaoBaoKit",
            targets: ["BaoBaoKit"]),
    ],
    dependencies: [
        // 添加项目所需的依赖
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.1"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.1"),
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.18.10"),
        .package(url: "https://github.com/realm/realm-swift.git", from: "10.45.3"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.6.0")
    ],
    targets: [
        .target(
            name: "BaoBaoKit",
            dependencies: [
                "Alamofire",
                "SwiftyJSON",
                .product(name: "SDWebImage", package: "SDWebImage"),
                .product(name: "RealmSwift", package: "realm-swift"),
                "RxSwift",
                .product(name: "RxCocoa", package: "RxSwift")
            ],
            path: "Sources/BaoBao"
        ),
        .testTarget(
            name: "BaoBaoKitTests",
            dependencies: ["BaoBaoKit"],
            path: "Tests/baobaoTests"
        ),
    ]
)
