// swift-tools-version: 6.0
// Reference solutions for the coding challenges and their tests (Swift Testing).
// Run every test with:  swift test
// Just one challenge:   swift test --filter TwoSumTests
import PackageDescription

let package = Package(
    name: "AcademyChallenges",
    products: [
        .library(name: "Challenges", targets: ["Challenges"]),
    ],
    targets: [
        .target(name: "Challenges"),
        .testTarget(name: "ChallengesTests", dependencies: ["Challenges"]),
        // Compiles and runs the snippets in content/lessons/ and compares their output.
        .testTarget(name: "LessonSnippetsTests"),
    ]
)
