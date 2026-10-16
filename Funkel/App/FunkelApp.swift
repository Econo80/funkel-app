import SwiftUI
import SwiftData

@main
struct FunkelApp: App {
    @State private var environment = AppEnvironment.live()
    private let container: ModelContainer

    init() {
        container = AppLaunch.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
        }
        .modelContainer(container)
    }
}
