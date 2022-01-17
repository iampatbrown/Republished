// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "Republished",
  platforms: [
    .iOS(.v14),
    .macOS(.v11),
    .tvOS(.v14),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "Republished",
      targets: ["Republished"]
    ),
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "Republished",
      dependencies: []
    ),
    .testTarget(
      name: "RepublishedTests",
      dependencies: ["Republished"]
    ),
  ]
)
