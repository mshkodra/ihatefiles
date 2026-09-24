import Foundation

/// Persisted user preferences, backed by `UserDefaults` via `@AppStorage`.
/// `SettingsView` reads/writes these; `ihatefilesApp` seeds `JobManager` from
/// `downloadConcurrencyLimit` at launch and keeps it live-synced afterward.
enum AppSettingsKey {
    static let downloadConcurrencyLimit = "downloadConcurrencyLimit"
    static let defaultOutputDirectory = "defaultOutputDirectory"
}

enum AppSettingsDefault {
    static let downloadConcurrencyLimit = 2

    static var defaultOutputDirectory: String {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
            ?? NSHomeDirectory()
    }
}

enum AppSettings {
    /// The user's configured download output directory, or the Downloads
    /// folder if unset. Read directly from `UserDefaults` so non-SwiftUI
    /// call sites (runner construction in view action methods) can use it
    /// without needing `@AppStorage` property-wrapper access.
    static var currentOutputDirectoryURL: URL {
        let path = UserDefaults.standard.string(forKey: AppSettingsKey.defaultOutputDirectory)
            ?? AppSettingsDefault.defaultOutputDirectory
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
