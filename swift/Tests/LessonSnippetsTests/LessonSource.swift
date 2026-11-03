import Foundation

/// Lee las lecciones de `content/lessons/` y extrae los fragmentos Swift que deben ejecutarse.
///
/// Reglas (documentadas en docs/CONTENIDO.md):
/// - Todo ejercicio `prediccion` de cualquier lección: su `code` se compila y ejecuta, y la salida
///   debe ser exactamente `output`.
/// - En lecciones con `codeStatus: probado`, además, cada bloque ```swift del texto y de las
///   soluciones de los ejercicios:
///   - ```swift                    → debe compilar y ejecutarse sin fallar. Si el siguiente bloque
///                                   cercado es ```output, la salida debe coincidir exactamente.
///   - ```swift no-compila <texto> → debe fallar al compilar y el diagnóstico debe contener <texto>.
///   - ```swift ilustrativo        → no se ejecuta (fragmentos que dependen de otro contexto,
///                                   código de Apple que no compila fuera de Xcode, etc.).
struct Snippet: Sendable, CustomStringConvertible {
    enum Expectation: Sendable, Equatable {
        case runs(output: String?)
        case failsToCompile(containing: String)
    }

    let lesson: String
    let location: String
    let code: String
    let expectation: Expectation

    var description: String { "\(lesson) · \(location)" }
}

struct LessonFile: Sendable {
    let path: String
    let id: String
    let codeStatus: String
    let body: String
}

enum LessonSource {
    static let repoRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // LessonSnippetsTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // swift
        .deletingLastPathComponent() // raíz

    static func lessonFiles() throws -> [LessonFile] {
        let dir = repoRoot.appendingPathComponent("content/lessons")
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        var files: [LessonFile] = []
        for case let url as URL in e where url.pathExtension == "md" {
            let text = try String(contentsOf: url, encoding: .utf8)
            let rel = String(url.path.dropFirst(repoRoot.path.count + 1))
            files.append(try parseLesson(path: rel, text: text))
        }
        return files.sorted { $0.path < $1.path }
    }

    static func parseLesson(path: String, text: String) throws -> LessonFile {
        let lines = text.components(separatedBy: "\n")
        guard lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") else {
            throw SnippetError.format("\(path): falta el frontmatter")
        }
        let front = lines[1..<end]
        func value(_ key: String) -> String? {
            front.first { $0.hasPrefix("\(key):") }.map {
                $0.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        guard let id = value("id"), let status = value("codeStatus") else {
            throw SnippetError.format("\(path): faltan id o codeStatus")
        }
        return LessonFile(path: path, id: id, codeStatus: status, body: lines[(end + 1)...].joined(separator: "\n"))
    }

    // MARK: Fragmentos

    static func predictionSnippets() throws -> [Snippet] {
        try lessonFiles().flatMap { lesson in
            try exercises(in: lesson).compactMap { ex -> Snippet? in
                guard ex.fields["type"] == "prediccion" else { return nil }
                guard let code = ex.blocks["code"], let output = ex.blocks["output"] else {
                    throw SnippetError.format("\(lesson.path) \(ex.id): code y output deben ser bloques `|`")
                }
                return Snippet(lesson: lesson.id, location: "\(ex.id) (predicción)", code: code, expectation: .runs(output: output))
            }
        }
    }

    /// Bloques de salida dentro de la solución de un ejercicio de predicción: deben repetir `output`.
    static func predictionSolutionOutputs() throws -> [(id: String, output: String, inSolution: String)] {
        try lessonFiles().flatMap { lesson in
            try exercises(in: lesson).flatMap { ex -> [(id: String, output: String, inSolution: String)] in
                guard ex.fields["type"] == "prediccion", let output = ex.blocks["output"], let sol = ex.blocks["solution"] else { return [] }
                return fences(in: sol).filter { $0.info == "output" }.map { (ex.id, output, $0.content) }
            }
        }
    }

    static func proseSnippets() throws -> [Snippet] {
        try lessonFiles().filter { $0.codeStatus == "probado" }.flatMap { lesson -> [Snippet] in
            let (prose, exs) = splitExercises(lesson.body)
            var result = snippets(fromMarkdown: prose, lesson: lesson.id, prefix: "texto")
            for ex in try exs.map(parseExercise) {
                if let sol = ex.blocks["solution"] {
                    result += snippets(fromMarkdown: sol, lesson: lesson.id, prefix: "\(ex.id) solución")
                }
            }
            return result
        }
    }

    static func snippets(fromMarkdown md: String, lesson: String, prefix: String) -> [Snippet] {
        let fs = fences(in: md)
        var result: [Snippet] = []
        for (i, f) in fs.enumerated() {
            let words = f.info.split(separator: " ", maxSplits: 1).map(String.init)
            guard words.first == "swift" else { continue }
            let modifier = words.count > 1 ? words[1] : ""
            let location = "\(prefix), bloque Swift en la línea \(f.line)"
            if modifier == "ilustrativo" { continue }
            if modifier.hasPrefix("no-compila") {
                let expected = modifier.dropFirst("no-compila".count).trimmingCharacters(in: .whitespaces)
                result.append(Snippet(lesson: lesson, location: location, code: f.content, expectation: .failsToCompile(containing: expected)))
                continue
            }
            let next = i + 1 < fs.count ? fs[i + 1] : nil
            let output = next?.info == "output" ? next?.content : nil
            result.append(Snippet(lesson: lesson, location: location, code: f.content, expectation: .runs(output: output)))
        }
        return result
    }

    // MARK: Markdown

    struct Fence { let info: String; let content: String; let line: Int }

    /// Bloques cercados con exactamente tres comillas invertidas.
    static func fences(in md: String) -> [Fence] {
        var result: [Fence] = []
        var open: (info: String, line: Int, lines: [String])?
        for (n, line) in md.components(separatedBy: "\n").enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            if var o = open {
                if t == "```" {
                    result.append(Fence(info: o.info, content: o.lines.joined(separator: "\n") + "\n", line: o.line))
                    open = nil
                } else {
                    o.lines.append(line)
                    open = o
                }
            } else if t.hasPrefix("```"), !t.hasPrefix("````") {
                open = (String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces), n + 1, [])
            }
        }
        return result
    }

    /// Separa la prosa de los bloques ````exercise.
    static func splitExercises(_ body: String) -> (prose: String, exercises: [String]) {
        var prose: [String] = []
        var exercises: [String] = []
        var current: [String]?
        for line in body.components(separatedBy: "\n") {
            if current == nil, line.trimmingCharacters(in: .whitespaces) == "````exercise" {
                current = []
            } else if current != nil, line.trimmingCharacters(in: .whitespaces) == "````" {
                exercises.append(current!.joined(separator: "\n"))
                current = nil
            } else if current != nil {
                current!.append(line)
            } else {
                prose.append(line)
            }
        }
        return (prose.joined(separator: "\n"), exercises)
    }

    // MARK: YAML mínimo de los ejercicios

    struct ParsedExercise {
        var id: String { fields["id"] ?? "sin id" }
        var fields: [String: String] = [:]
        /// Valores escritos como bloque literal `|` o `|-`, ya sin sangría.
        var blocks: [String: String] = [:]
    }

    static func exercises(in lesson: LessonFile) throws -> [ParsedExercise] {
        try splitExercises(lesson.body).exercises.map(parseExercise)
    }

    /// Lee solo las claves de primer nivel. Los bloques literales siguen las reglas de YAML:
    /// la sangría la fija la primera línea no vacía; `|` deja un único salto final y `|-` ninguno.
    static func parseExercise(_ yaml: String) throws -> ParsedExercise {
        var ex = ParsedExercise()
        let lines = yaml.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let line = lines[i]
            i += 1
            guard let first = line.first, first != " ", first != "-", first != "#",
                  let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon])
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard value == "|" || value == "|-" else {
                ex.fields[key] = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                continue
            }
            var body: [String] = []
            var indent: Int?
            while i < lines.count {
                let l = lines[i]
                let leading = l.prefix { $0 == " " }.count
                if l.trimmingCharacters(in: .whitespaces).isEmpty {
                    body.append("")
                } else {
                    if indent == nil { indent = leading }
                    guard let ind = indent, ind > 0, leading >= ind else { break }
                    body.append(String(l.dropFirst(ind)))
                }
                i += 1
            }
            while body.last == "" { body.removeLast() }
            let text = body.joined(separator: "\n")
            ex.blocks[key] = value == "|" && !body.isEmpty ? text + "\n" : text
        }
        return ex
    }
}

enum SnippetError: Error, CustomStringConvertible {
    case format(String)
    var description: String {
        switch self { case .format(let s): s }
    }
}
