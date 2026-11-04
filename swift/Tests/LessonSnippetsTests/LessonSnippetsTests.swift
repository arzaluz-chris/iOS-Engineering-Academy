import Testing

/// Runs the code in the lessons and checks it does what the lesson says it does.
/// The rules for what gets run live in `LessonSource`.
@Suite("Lesson snippets")
struct LessonSnippetsTests {
    @Test("Prediction exercises print exactly their expected output", arguments: try LessonSource.predictionSnippets())
    func prediccion(_ snippet: Snippet) throws {
        try check(snippet)
    }

    @Test("Swift blocks in tested lessons behave as the text says", arguments: try LessonSource.proseSnippets())
    func bloques(_ snippet: Snippet) throws {
        try check(snippet)
    }

    @Test("iOS blocks type-check against the iOS SDK", .enabled(if: SwiftRunner.iosSDKPath != nil), arguments: try LessonSource.iosSnippets())
    func iosBlocks(_ snippet: IOSSnippet) throws {
        let diagnostics = try SwiftRunner.typecheckForIOS(snippet.code, deploymentTarget: snippet.deploymentTarget)
        #expect(diagnostics == nil, "Doesn't type-check for iOS \(snippet.deploymentTarget):\n\(diagnostics ?? "")")
    }

    /// Proves the iOS check is real: UIKit code passes, and a mistake in it fails.
    @Test("The iOS type-check accepts UIKit code and rejects broken code", .enabled(if: SwiftRunner.iosSDKPath != nil))
    func iosCheckWorks() throws {
        let good = """
            import UIKit

            final class GreetingViewController: UIViewController {
                private let label = UILabel()

                override func viewDidLoad() {
                    super.viewDidLoad()
                    label.text = "Hello"
                    view.addSubview(label)
                }
            }
            """
        #expect(try SwiftRunner.typecheckForIOS(good, deploymentTarget: IOSSnippet.defaultTarget) == nil)
        let bad = good.replacingOccurrences(of: "label.text = \"Hello\"", with: "label.txt = \"Hello\"")
        let diagnostics = try SwiftRunner.typecheckForIOS(bad, deploymentTarget: IOSSnippet.defaultTarget)
        #expect(diagnostics?.contains("has no member 'txt'") == true, "\(diagnostics ?? "no diagnostics")")
    }

    @Test("A prediction solution repeats its output exactly")
    func solucionesConsistentes() throws {
        for item in try LessonSource.predictionSolutionOutputs() {
            #expect(item.inSolution == item.output, "\(item.id): the output block in the solution doesn't match the output field")
        }
    }

    @Test("The extractor finds the prediction exercises")
    func extractorFunciona() throws {
        let ids = try LessonSource.predictionSnippets().map(\.location)
        #expect(ids.contains { $0.hasPrefix("m04-l01-e2") })
        #expect(ids.contains { $0.hasPrefix("m01-l02-e2") })
    }

    private func check(_ snippet: Snippet) throws {
        let result = try SwiftRunner.run(snippet.code)
        switch snippet.expectation {
        case .runs(let expected, let warning):
            try #require(result.compiled, "Doesn't compile:\n\(result.diagnostics)")
            #expect(result.exitCode == 0, "Exited with code \(result.exitCode):\n\(result.diagnostics)")
            if let expected {
                #expect(result.stdout == expected)
            }
            if let warning {
                #expect(result.diagnostics.contains("warning: \(warning)"), "Missing warning \"\(warning)\":\n\(result.diagnostics)")
            }
        case .crashes(let message, let expected):
            try #require(result.compiled, "Doesn't compile:\n\(result.diagnostics)")
            #expect(result.exitCode != 0, "Expected a runtime error")
            #expect(result.diagnostics.contains(message), "The run didn't report \"\(message)\":\n\(result.diagnostics)")
            if let expected {
                #expect(result.stdout == expected)
            }
        case .prints(let expected):
            try #require(result.compiled, "Doesn't compile:\n\(result.diagnostics)")
            #expect(result.stdout == expected)
        case .failsToCompile(let message):
            #expect(!result.compiled, "Expected a compile error")
            #expect(result.diagnostics.contains(message), "The diagnostic doesn't contain \"\(message)\":\n\(result.diagnostics)")
        }
    }
}
