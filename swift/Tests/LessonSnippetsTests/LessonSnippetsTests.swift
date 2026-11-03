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
