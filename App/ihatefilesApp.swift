import SwiftUI

@main
struct ihatefilesApp: App {
    @State private var jobManager = JobManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(jobManager)
        }
    }
}
