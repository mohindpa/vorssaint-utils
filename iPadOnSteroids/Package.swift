// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "iPadWorkspaceCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "iPadWorkspaceCore", targets: ["iPadOnSteroids"])],
    targets: [
        .target(name: "iPadOnSteroids", path: "App", exclude: ["Dashboard.swift", "Store.swift", "Style.swift", "WorkspaceViews.swift", "ImageTextView.swift", "iPadOnSteroidsApp.swift", "PrivacyInfo.xcprivacy"], sources: ["Core.swift"]),
        .testTarget(name: "iPadWorkspaceCoreTests", dependencies: ["iPadOnSteroids"], path: "Tests")
    ]
)
