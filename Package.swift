import PackageDescription

let package = Package(
    name: "WebAppKit",
    dependencies: [
        .Package(url: "https://github.com/noppoMan/Prorsum.git", majorVersion: 0, minor: 1)
    ]
)
