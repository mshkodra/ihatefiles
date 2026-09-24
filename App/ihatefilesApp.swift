import SwiftUI

@main
struct ihatefilesApp: App {
    @State private var jobManager = JobManager(
        downloadConcurrencyLimit: UserDefaults.standard.object(forKey: AppSettingsKey.downloadConcurrencyLimit) as? Int
            ?? AppSettingsDefault.downloadConcurrencyLimit
    )

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(jobManager)
        }

        MenuBarExtra {
            MenuBarExtraView()
                .environment(jobManager)
        } label: {
            MenuBarExtraLabel()
                .environment(jobManager)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(jobManager)
        }
    }
}
