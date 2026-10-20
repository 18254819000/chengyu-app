import SwiftUI

@main
struct DailyIdiomApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(state.store)
        }
    }
}
