import Darwin
import SwiftUI

@main
struct ihatefilesApp: App {
    @State private var jobManager = JobManager()

    init() {
        #if DEBUG
        Self.debugCheckBundledBinaries()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(jobManager)
        }
    }

    #if DEBUG
    /// Temporary Phase 3 verification: confirms BinaryLocator resolves both
    /// vendored binaries and that they actually execute. Remove once Phase 4
    /// exercises yt-dlp/ffmpeg for real.
    private static func debugCheckBundledBinaries() {
        setvbuf(stdout, nil, _IONBF, 0)
        for (name, urlProvider, versionFlag) in [
            ("yt-dlp", { try BinaryLocator.ytDlpURL }, "--version"),
            ("ffmpeg", { try BinaryLocator.ffmpegURL }, "-version"),
        ] as [(String, () throws -> URL, String)] {
            do {
                let url = try urlProvider()
                let process = Process()
                process.executableURL = url
                process.arguments = [versionFlag]
                let pipe = Pipe()
                process.standardOutput = pipe
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "<no output>"
                print("[BinaryCheck] \(name): \(output.split(separator: "\n").first ?? "")")
            } catch {
                print("[BinaryCheck] \(name) FAILED: \(error)")
            }
        }
    }
    #endif
}
