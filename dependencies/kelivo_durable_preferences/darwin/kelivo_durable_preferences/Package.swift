// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "kelivo_durable_preferences",
  platforms: [
    .iOS("14.0"),
    .macOS("10.15"),
  ],
  products: [
    .library(
      name: "kelivo-durable-preferences",
      targets: ["kelivo_durable_preferences"]
    )
  ],
  targets: [
    .target(
      name: "kelivo_durable_preferences",
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "kelivo_durable_preferencesTests",
      dependencies: ["kelivo_durable_preferences"],
      path: "../Tests"
    ),
  ]
)
