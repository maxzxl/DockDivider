import Foundation

enum ProcessRunner {
    @discardableResult
    static func run(_ executable: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        // Drain before waiting to avoid pipe-buffer deadlocks.
        let output = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw DockError.io("\(URL(fileURLWithPath: executable).lastPathComponent): \(String(data: output, encoding: .utf8) ?? L10n.string("error.process"))")
        }
        return process.terminationStatus
    }
    static func reloadDock() throws {
        // -u limits the operation to this user; no sudo and no cfprefsd restart.
        try run("/usr/bin/killall", ["-u", NSUserName(), "Dock"])
    }
}
