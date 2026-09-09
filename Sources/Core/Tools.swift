import Foundation

/// Finds the external binaries LocalFlow shells out to: `ffmpeg`,
/// `whisper-server`, `whisper-cli`.
///
/// These used to be hardcoded to `/opt/homebrew/bin`, which is Apple Silicon
/// Homebrew. That path does not exist on an Intel Mac (Homebrew lives in
/// `/usr/local` there) and obviously not on Windows, so the same hardcode was
/// behind two separate bugs.
enum Tools {
    /// Searched in order. The Homebrew prefixes come first on macOS so behaviour
    /// matches what LocalFlow has always done; a GUI app launched by launchd
    /// inherits a minimal `PATH`, so relying on the environment alone would
    /// find nothing.
    static var searchDirectories: [String] {
        #if os(Windows)
        return (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ";").map(String.init)
        #else
        let fromEnvironment = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map(String.init)
        return ["/opt/homebrew/bin", "/usr/local/bin"] + fromEnvironment + ["/usr/bin", "/bin"]
        #endif
    }

    /// The located binary, or nil when the user has not installed it yet.
    /// Callers should say which `brew install` or download is missing rather
    /// than failing with a bare path error.
    static func url(for tool: String) -> URL? {
        #if os(Windows)
        let names = ["\(tool).exe", "\(tool).cmd", tool]
        #else
        let names = [tool]
        #endif
        for directory in searchDirectories {
            for name in names {
                let candidate = URL(fileURLWithPath: directory).appendingPathComponent(name)
                if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
            }
        }
        return nil
    }

    /// `PATH` handed to child processes, so a tool that shells out to another
    /// tool finds it too.
    static var childProcessPath: String {
        #if os(Windows)
        return ProcessInfo.processInfo.environment["PATH"] ?? ""
        #else
        return searchDirectories.joined(separator: ":")
        #endif
    }
}
