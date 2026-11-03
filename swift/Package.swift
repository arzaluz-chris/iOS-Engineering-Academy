// swift-tools-version: 6.0
// Soluciones de referencia de los retos de código y sus pruebas (Swift Testing).
// Ejecuta todas las pruebas con:  swift test
// Solo un reto:                    swift test --filter TwoSumTests
import PackageDescription

let package = Package(
    name: "AcademyChallenges",
    products: [
        .library(name: "Challenges", targets: ["Challenges"]),
    ],
    targets: [
        .target(name: "Challenges"),
        .testTarget(name: "ChallengesTests", dependencies: ["Challenges"]),
        // Compila y ejecuta los fragmentos de content/lessons/ y compara su salida.
        .testTarget(name: "LessonSnippetsTests"),
    ]
)
