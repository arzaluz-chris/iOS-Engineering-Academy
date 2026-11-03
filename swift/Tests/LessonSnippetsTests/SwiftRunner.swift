import Foundation

/// Compiles a snippet as a standalone program (`main.swift`, Swift 6 language mode) and runs it.
enum SwiftRunner {
    struct Result {
        let compiled: Bool
        let diagnostics: String
        let exitCode: Int32
        let stdout: String
    }

    /// Line-buffered output, like a terminal or the Xcode console. Without this, when stdout is a
    /// pipe, anything printed before a runtime error stays in the buffer and is lost.
    static let prelude = """
        #if canImport(Darwin)
        @preconcurrency import Darwin
        #elseif canImport(Glibc)
        @preconcurrency import Glibc
        #endif
        setvbuf(stdout, nil, _IOLBF, 0)

        """

    static func run(_ code: String) throws -> Result {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lesson-snippet-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("main.swift")
        let binary = dir.appendingPathComponent("snippet")
        try (prelude + code).write(to: source, atomically: true, encoding: .utf8)

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
        // Drop test-process variables that would change how the program links.
        p.environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("DYLD_") }
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = FileHandle.nullDevice
        try p.run()
        // Read before waiting so a full pipe buffer can't deadlock.
        let o = out.fileHandleForReading.readDataToEndOfFile()
        let e = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: o, as: UTF8.self), String(decoding: e, as: UTF8.self))
    }
}
