import Foundation

/// Reads the lessons in `content/lessons/` and pulls out the Swift code that has to run.
///
/// Rules (documented in docs/CONTENT.md):
/// - Every `prediction` exercise in any lesson: its `code` is compiled and run, and what it prints
///   must be exactly `output`.
/// - In lessons with `codeStatus: tested`, also every ```swift block in the prose and in exercise
///   solutions:
///   - ```swift                    → must compile and run cleanly. If the next fenced block is
///                                   ```output, what it prints must match exactly.
///   - ```swift no-compile <text>  → must fail to compile with a diagnostic containing <text>.
///   - ```swift warning <text>     → must compile with a warning containing <text> and run cleanly
///                                   (with ```output, the output is compared).
///   - ```swift runtime-error <text> → must compile, stop with a runtime error and
///                                   write <text> to stderr (with ```output, stdout is compared).
///   - ```swift illustrative       → not run (code that depends on another block, Apple
///                                   frameworks that don't build outside Xcode, and so on).
struct Snippet: Sendable, CustomStringConvertible {
    enum Expectation: Sendable, Equatable {
        case runs(output: String?, warning: String? = nil)
        case failsToCompile(containing: String)
        case crashes(containing: String, output: String?)
        /// Prediction exercise: must compile and its standard output must be exactly this.
        /// It may stop with a runtime error if that's what the exercise is about.
        case prints(String)
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
        .deletingLastPathComponent() // repository root

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
                guard ex.fields["type"] == "prediction" else { return nil }
                guard let code = ex.blocks["code"], let output = ex.blocks["output"] else {
                    throw SnippetError.format("\(lesson.path) \(ex.id): code y output deben ser bloques `|`")
                }
                if ex.fields["lang"] == "pseudo" {
                    // Pseudocode can't run, so run the Swift translation from the solution instead.
                    guard let swift = fences(in: ex.blocks["solution"] ?? "").first(where: { $0.info == "swift" }) else {
                        throw SnippetError.format("\(lesson.path) \(ex.id): the solution is missing its Swift translation")
                    }
                    return Snippet(lesson: lesson.id, location: "\(ex.id) (prediction, Swift translation)", code: swift.content, expectation: .prints(output))
                }
                return Snippet(lesson: lesson.id, location: "\(ex.id) (prediction)", code: code, expectation: .prints(output))
            }
        }
    }

    /// Output blocks inside a prediction solution, which must repeat `output`.
    static func predictionSolutionOutputs() throws -> [(id: String, output: String, inSolution: String)] {
        try lessonFiles().flatMap { lesson in
            try exercises(in: lesson).flatMap { ex -> [(id: String, output: String, inSolution: String)] in
                guard ex.fields["type"] == "prediction", let output = ex.blocks["output"], let sol = ex.blocks["solution"] else { return [] }
                return fences(in: sol).filter { $0.info == "output" }.map { (ex.id, output, $0.content) }
            }
        }
    }

    static func proseSnippets() throws -> [Snippet] {
        try lessonFiles().filter { $0.codeStatus == "tested" }.flatMap { lesson -> [Snippet] in
            let (prose, exs) = splitExercises(lesson.body)
            var result = snippets(fromMarkdown: prose, lesson: lesson.id, prefix: "prose")
            for ex in try exs.map(parseExercise) {
                if let sol = ex.blocks["solution"] {
                    result += snippets(fromMarkdown: sol, lesson: lesson.id, prefix: "\(ex.id) solution")
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
            let location = "\(prefix), Swift block at line \(f.line)"
            if modifier == "illustrative" { continue }
            if modifier.hasPrefix("no-compile") {
                let expected = modifier.dropFirst("no-compile".count).trimmingCharacters(in: .whitespaces)
                result.append(Snippet(lesson: lesson, location: location, code: f.content, expectation: .failsToCompile(containing: expected)))
                continue
            }
            let next = i + 1 < fs.count ? fs[i + 1] : nil
            let output = next?.info == "output" ? next?.content : nil
            func rest(_ prefix: String) -> String {
                modifier.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            }
            let expectation: Snippet.Expectation
            if modifier.hasPrefix("warning") {
                expectation = .runs(output: output, warning: rest("warning"))
            } else if modifier.hasPrefix("runtime-error") {
                expectation = .crashes(containing: rest("runtime-error"), output: output)
            } else if modifier.isEmpty {
                expectation = .runs(output: output)
            } else {
                // An unknown marker is a typo in the lesson, so make the test say so.
                expectation = .failsToCompile(containing: "unknown block marker \"\(modifier)\"")
            }
            result.append(Snippet(lesson: lesson, location: location, code: f.content, expectation: expectation))
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

    /// Splits the prose from the ````exercise blocks.
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

    // MARK: Minimal YAML for exercises

    struct ParsedExercise {
        var id: String { fields["id"] ?? "sin id" }
        var fields: [String: String] = [:]
        /// Values written as `|` or `|-` literal blocks, with the indentation removed.
        var blocks: [String: String] = [:]
    }

    static func exercises(in lesson: LessonFile) throws -> [ParsedExercise] {
        try splitExercises(lesson.body).exercises.map(parseExercise)
    }

    /// Reads top-level keys only. Literal blocks follow YAML's rules: the first non-empty line sets
    /// the indentation; `|` keeps a single trailing newline and `|-` keeps none.
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
            // Literal block: `|`, `|-`, or with an indentation indicator `|2`, `|2-` or `|-2`.
            guard value.first == "|", value.count <= 3,
                  value.dropFirst().allSatisfy({ $0 == "-" || $0.isNumber }) else {
                ex.fields[key] = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                continue
            }
            let strip = value.contains("-")
            var body: [String] = []
            var indent: Int? = value.first(where: \.isNumber).flatMap { Int(String($0)) }
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
            ex.blocks[key] = !strip && !body.isEmpty ? text + "\n" : text
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
