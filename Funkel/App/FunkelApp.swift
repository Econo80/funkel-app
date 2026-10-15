import SwiftUI
import SwiftData

@main
struct FunkelApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
        }
        .modelContainer(for: [ChildProfile.self, SubjectProgress.self, RoundRecord.self])
    }
}
