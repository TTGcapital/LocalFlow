import Foundation

/// Every filesystem location LocalFlow uses, resolved in one place.
///
/// macOS keeps the `~/Library/Application Support/LocalFlow` layout the app has
/// always used; a Windows build resolves the same names under `%APPDATA%`.
/// Nothing outside this type should build a path from the home directory — that
/// is what made the original code macOS-only in five separate files.
///
/// The resolution is written as a function of `(platform, environment, home)`
/// rather than as `#if` blocks around the values, so the Windows layout can be
/// tested from a Mac. Code inside `#if os(Windows)` that only ever compiles on
/// a Windows CI runner is code nobody has actually run.
enum AppPaths {
    enum Platform {
        case apple
        case windows
    }

    static var current: Platform {
        #if os(Windows)
        return .windows
        #else
        return .apple
        #endif
    }

    private static var environment: [String: String] { ProcessInfo.processInfo.environment }
    private static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    // MARK: Resolution

    static func root(platform: Platform, environment: [String: String], home: URL) -> URL {
        switch platform {
        case .windows:
            // %APPDATA% is roaming application data. Falling back to the literal
            // path matters: a service or a stripped environment may not set it.
            let base = environment["APPDATA"].map(URL.init(fileURLWithPath:))
                ?? home.appendingPathComponent("AppData/Roaming")
            return base.appendingPathComponent("LocalFlow")
        case .apple:
            return home.appendingPathComponent("Library/Application Support/LocalFlow")
        }
    }

    /// The `claude` CLI. Installed per user on both platforms, under different
    /// names and in different places.
    static func claudeExecutable(platform: Platform, environment: [String: String], home: URL) -> URL {
        switch platform {
        case .windows:
            let appData = environment["APPDATA"].map(URL.init(fileURLWithPath:))
                ?? home.appendingPathComponent("AppData/Roaming")
            return appData.appendingPathComponent("npm/claude.cmd")
        case .apple:
            return home.appendingPathComponent(".local/bin/claude")
        }
    }

    // MARK: The paths the app uses

    static var root: URL { root(platform: current, environment: environment, home: home) }
    static var claudeExecutable: URL { claudeExecutable(platform: current, environment: environment, home: home) }

    static var models: URL { root.appendingPathComponent("Models") }
    static var claudeWorkingDirectory: URL { root.appendingPathComponent("Claude") }

    /// Whisper weights, downloaded once by `scripts/download-models.sh`.
    static var largeModel: URL { models.appendingPathComponent("ggml-large-v3-turbo-q5_0.bin") }
    static var baseModel: URL { models.appendingPathComponent("ggml-base-q5_1.bin") }
}
