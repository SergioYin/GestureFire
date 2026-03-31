// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GestureFire",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/Kyome22/OpenMultitouchSupport.git", from: "3.0.3"),
    ],
    targets: [
        // MARK: - Libraries

        .target(
            name: "GestureFireTypes",
            path: "Sources/GestureFireTypes"
        ),
        .target(
            name: "GestureFireRecognition",
            dependencies: ["GestureFireTypes"],
            path: "Sources/GestureFireRecognition"
        ),
        .target(
            name: "GestureFireIntegration",
            dependencies: ["GestureFireTypes", "OpenMultitouchSupport"],
            path: "Sources/GestureFireIntegration"
        ),
        .target(
            name: "GestureFireShortcuts",
            dependencies: ["GestureFireTypes"],
            path: "Sources/GestureFireShortcuts"
        ),
        .target(
            name: "GestureFireConfig",
            dependencies: ["GestureFireTypes"],
            path: "Sources/GestureFireConfig"
        ),
        .target(
            name: "GestureFireEngine",
            dependencies: [
                "GestureFireTypes",
                "GestureFireRecognition",
                "GestureFireIntegration",
                "GestureFireShortcuts",
                "GestureFireConfig",
            ],
            path: "Sources/GestureFireEngine"
        ),

        // MARK: - App

        .executableTarget(
            name: "GestureFireApp",
            dependencies: ["GestureFireEngine"],
            path: "Sources/GestureFireApp",
            exclude: ["Info.plist"]
        ),

        // MARK: - Tests

        .testTarget(
            name: "GestureFireTypesTests",
            dependencies: ["GestureFireTypes"],
            path: "Tests/GestureFireTypesTests"
        ),
        .testTarget(
            name: "GestureFireRecognitionTests",
            dependencies: ["GestureFireRecognition", "GestureFireTypes"],
            path: "Tests/GestureFireRecognitionTests"
        ),
        .testTarget(
            name: "GestureFireShortcutsTests",
            dependencies: ["GestureFireShortcuts", "GestureFireTypes"],
            path: "Tests/GestureFireShortcutsTests"
        ),
        .testTarget(
            name: "GestureFireConfigTests",
            dependencies: ["GestureFireConfig", "GestureFireTypes"],
            path: "Tests/GestureFireConfigTests"
        ),
        .testTarget(
            name: "GestureFireEngineTests",
            dependencies: ["GestureFireEngine", "GestureFireTypes"],
            path: "Tests/GestureFireEngineTests"
        ),
    ]
)
