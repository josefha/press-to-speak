// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PressToSpeak",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PressToSpeakApp", targets: ["PressToSpeakApp"])
    ],
    targets: [
        .target(name: "PressToSpeakCore"),
        .target(name: "PressToSpeakInfra", dependencies: ["PressToSpeakCore"]),
        .executableTarget(
            name: "PressToSpeakApp",
            dependencies: ["PressToSpeakCore", "PressToSpeakInfra"]
        )
    ]
)
