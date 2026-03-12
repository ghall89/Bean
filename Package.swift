// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "Bean",
	platforms: [.macOS(.v26)],
	dependencies: [
		.package(url: "https://github.com/pointfreeco/sqlite-data.git", from: "1.6.0"),
		.package(url: "https://github.com/simonbs/SFSymbols.git", from: "1.4.0"),
	],
	targets: [
		.executableTarget(
			name: "Bean",
			dependencies: [
				.product(name: "SQLiteData", package: "sqlite-data"),
				.product(name: "SFSymbols", package: "sfsymbols"),
			],
		),
	],
)
