import Foundation

/// Every filesystem location LocalFlow uses, resolved in one place.
///
/// macOS keeps the `~/Library/Application Support/LocalFlow` layout the app has
/// always used; a Windows build resolves the same names under `%APPDATA%`.
/// Nothing outside this type should build a path from the home directory — that
/// is what made the original code macOS-only in five separate files.
enum AppPaths {
    /// Root for models, audio, the archive and the Claude working directory.
    static let root: URL = {
        #if os(Windows)
        let base = ProcessInfo.processInfo.environment["APPDATA"].map(URL.init(fileURLWithPath:))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("AppData/Roaming")
        return base.appendingPathComponent("LocalFlow")
        #else
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/LocalFlow")
        #endif
    }()

    static var models: URL { root.appendingPathComponent("Models") }
    static var claudeWorkingDirectory: URL { root.appendingPathComponent("Claude") }

    /// Whisper weights, downloaded once by `scripts/download-models.sh`.
    static var largeModel: URL { models.appendingPathComponent("ggml-large-v3-turbo-q5_0.bin") }
    static var baseModel: URL { models.appendingPathComponent("ggml-base-q5_1.bin") }

    /// The `claude` CLI. Installed per user on both platforms, under different
    /// names: the npm global bin on Windows, `~/.local/bin` on macOS.
    static var claudeExecutable: URL {
        #if os(Windows)
        let appData = ProcessInfo.processInfo.environment["APPDATA"].map(URL.init(fileURLWithPath:))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("AppData/Roaming")
        return appData.appendingPathComponent("npm/claude.cmd")
        #else
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/claude")
        #endif
    }
}
