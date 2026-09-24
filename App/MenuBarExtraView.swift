import AppKit
import SwiftUI

/// Content of the menu bar extra (see the `MenuBarExtra` scene in
/// `ihatefilesApp`). Reads the same shared `JobManager` via `@Environment`
/// as every other view, so its counts are always live — never a stale
/// snapshot taken when the menu bar item was created.
struct MenuBarExtraView: View {
    @Environment(JobManager.self) private var jobManager
    @Environment(\.openWindow) private var openWindow

    private var runningCount: Int { jobManager.jobs.filter { $0.status == .running }.count }
    private var queuedCount: Int { jobManager.jobs.filter { $0.status == .queued }.count }
    private var doneCount: Int { jobManager.jobs.filter { $0.status == .done }.count }

    var body: some View {
        Text("\(runningCount) running · \(queuedCount) queued · \(doneCount) done")
        Divider()
        Button("Open ihatefiles") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit ihatefiles") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

/// Label for the menu bar item itself — a compact live count, since the
/// full breakdown lives in the dropdown above.
struct MenuBarExtraLabel: View {
    @Environment(JobManager.self) private var jobManager

    private var activeCount: Int {
        jobManager.jobs.filter { $0.status == .running || $0.status == .queued }.count
    }

    var body: some View {
        if activeCount > 0 {
            Label("\(activeCount)", systemImage: "shippingbox.fill")
        } else {
            Image(systemName: "shippingbox")
        }
    }
}
