import SwiftUI

@main
struct TimeTrackerApp: App {
    @StateObject private var timerViewModel = TimerViewModel.shared

    init() {
        DatabaseManager.prepareStorageIfNeeded()
        _ = DatabaseManager.shared
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MainTabView()
                .frame(minWidth: 620, minHeight: 700)
                .environmentObject(timerViewModel)
                .preferredColorScheme(.dark)
                .configureMacWindow()
        }
        .defaultSize(width: 920, height: 760)
        .windowResizability(.contentMinSize)

        WindowGroup(id: "miniplayer") {
            MiniPlayerView()
                .environmentObject(timerViewModel)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 680, height: 74)
    }
}
