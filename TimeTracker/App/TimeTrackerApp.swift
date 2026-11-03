import SwiftUI

@main
struct TimeTrackerApp: App {
    @StateObject private var timerViewModel = TimerViewModel.shared
    @StateObject private var updater = Updater.shared

    /// Unit tests run inside the app. They bring their own databases, so the app itself opens
    /// none and doesn't ask GitHub for releases.
    static let isRunningUnitTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    init() {
        guard !Self.isRunningUnitTests else { return }
        DatabaseManager.prepareStorageIfNeeded()
        Updater.shared.start()
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            if Self.isRunningUnitTests {
                Color.clear
            } else {
                MainTabView()
                    .frame(minWidth: 620, minHeight: 700)
                    .environmentObject(timerViewModel)
                    .preferredColorScheme(.dark)
                    .configureMacWindow()
            }
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
