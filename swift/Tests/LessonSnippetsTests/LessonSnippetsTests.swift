import Testing

/// Ejecuta los fragmentos de las lecciones y compara su salida con la que la lección afirma.
/// Las reglas de qué se ejecuta están en `LessonSource`.
@Suite("Fragmentos de las lecciones")
struct LessonSnippetsTests {
    @Test("Las salidas de los ejercicios de predicción son exactas", arguments: try LessonSource.predictionSnippets())
    func prediccion(_ snippet: Snippet) throws {
        try check(snippet)
    }

    @Test("Los bloques Swift de las lecciones probadas se comportan como dice el texto", arguments: try LessonSource.proseSnippets())
    func bloques(_ snippet: Snippet) throws {
        try check(snippet)
    }

    @Test("La solución de un ejercicio de predicción repite exactamente su output")
    func solucionesConsistentes() throws {
        for item in try LessonSource.predictionSolutionOutputs() {
            #expect(item.inSolution == item.output, "\(item.id): el bloque output de la solución no coincide con el campo output")
        }
    }

    @Test("El extractor encuentra los ejercicios de predicción")
    func extractorFunciona() throws {
        let ids = try LessonSource.predictionSnippets().map(\.location)
        #expect(ids.contains { $0.hasPrefix("m04-l01-e2") })
        #expect(ids.contains { $0.hasPrefix("m01-l02-e2") })
    }

    private func check(_ snippet: Snippet) throws {
        let result = try SwiftRunner.run(snippet.code)
        switch snippet.expectation {
        case .runs(let expected):
            try #require(result.compiled, "No compila:\n\(result.diagnostics)")
            #expect(result.exitCode == 0, "Terminó con código \(result.exitCode):\n\(result.diagnostics)")
            if let expected {
                #expect(result.stdout == expected)
            }
        case .failsToCompile(let message):
            #expect(!result.compiled, "Se esperaba un error de compilación")
            #expect(result.diagnostics.contains(message), "El diagnóstico no contiene «\(message)»:\n\(result.diagnostics)")
        }
    }
}
