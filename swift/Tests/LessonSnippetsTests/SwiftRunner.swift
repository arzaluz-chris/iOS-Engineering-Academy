import Foundation

/// Compila un fragmento como programa independiente (`main.swift`, modo de lenguaje Swift 6) y lo ejecuta.
enum SwiftRunner {
    struct Result {
        let compiled: Bool
        let diagnostics: String
        let exitCode: Int32
        let stdout: String
    }

    static func run(_ code: String) throws -> Result {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lesson-snippet-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("main.swift")
        let binary = dir.appendingPathComponent("snippet")
        try code.write(to: source, atomically: true, encoding: .utf8)

        let compile = try exec("/usr/bin/env", ["swiftc", "-swift-version", "6", source.path, "-o", binary.path])
        guard compile.status == 0 else {
            return Result(compiled: false, diagnostics: compile.stderr + compile.stdout, exitCode: compile.status, stdout: "")
        }
        let run = try exec(binary.path, [])
        return Result(compiled: true, diagnostics: compile.stderr + run.stderr, exitCode: run.status, stdout: run.stdout)
    }

    private static func exec(_ path: String, _ args: [String]) throws -> (status: Int32, stdout: String, stderr: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        // Sin variables del proceso de pruebas que alteren el enlazado del programa.
        p.environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("DYLD_") }
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = FileHandle.nullDevice
        try p.run()
        // Leer antes de esperar evita bloqueos si la salida llena el búfer del pipe.
        let o = out.fileHandleForReading.readDataToEndOfFile()
        let e = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: o, as: UTF8.self), String(decoding: e, as: UTF8.self))
    }
}
