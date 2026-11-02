import SwiftUI

@main
struct TimeTrackerApp: App {
    @StateObject private var timerViewModel = TimerViewModel.shared
    @StateObject private var updater = Updater.shared

    init() {
        DatabaseManager.prepareStorageIfNeeded()
        _ = DatabaseManager.shared

        // Unit tests run inside the app; they shouldn't ask GitHub for releases.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            Updater.shared.start()
        }
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
        .commands {
            UpdateCommands(updater: updater)
        }

        WindowGroup(id: "miniplayer") {
            MiniPlayerView()
                .environmentObject(timerViewModel)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 680, height: 74)
    }
}
