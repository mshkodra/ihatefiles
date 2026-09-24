import SwiftUI

/// The app's Settings scene (⌘,). Changing the concurrency slider here
/// writes straight through to the shared `JobManager` instance via
/// `.onChange`, so the running queue respects it immediately — not just on
/// next launch — while `@AppStorage` handles persistence across relaunches.
struct SettingsView: View {
    @Environment(JobManager.self) private var jobManager

    @AppStorage(AppSettingsKey.downloadConcurrencyLimit)
    private var downloadConcurrencyLimit = AppSettingsDefault.downloadConcurrencyLimit

    @AppStorage(AppSettingsKey.defaultOutputDirectory)
    private var defaultOutputDirectory = AppSettingsDefault.defaultOutputDirectory

    var body: some View {
        Form {
            Section("Downloads") {
                Stepper(
                    "Concurrent downloads: \(downloadConcurrencyLimit)",
                    value: $downloadConcurrencyLimit,
                    in: 1...6
                )
                .help("How many downloads run at once. Extra ones queue until a slot frees. Conversions are never limited by this.")

                LabeledContent("Save to") {
                    Text(defaultOutputDirectory)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Button("Choose…", action: chooseOutputDirectory)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onChange(of: downloadConcurrencyLimit) { _, newValue in
            jobManager.downloadConcurrencyLimit = newValue
        }
    }

    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: defaultOutputDirectory, isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        defaultOutputDirectory = url.path
    }
}

#Preview {
    SettingsView()
        .environment(JobManager())
}
