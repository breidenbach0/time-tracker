import AppKit
import SwiftUI

/// News about TimeTracker updates, floating at the bottom of the window: a newer version to
/// install, how installing it is going, or what went wrong. Nothing when there's no news.
struct UpdateCard: View {
    @ObservedObject var updater: Updater

    var body: some View {
        Group {
            switch updater.state {
            case .idle:
                EmptyView()
            case .checking:
                card { progress("Checking for updates…") }
            case .available(let release):
                card { available(release) }
            case .installing(_, let step):
                card { progress(step, detail: "TimeTracker starts again when it’s done. A running recording keeps going.") }
            case .needsRestart(let version):
                card {
                    note("TimeTracker \(version) is installed", detail: "Open TimeTracker again to start using it.",
                         symbol: "checkmark.circle.fill", color: AppTheme.success)
                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        actionLabel("Quit TimeTracker", prominent: true)
                    }
                    .buttonStyle(.glassCapsule(tint: AppTheme.accent.opacity(0.92)))
                }
            case .updated(let version):
                card {
                    note("Updated to TimeTracker \(version)", detail: nil,
                         symbol: "checkmark.circle.fill", color: AppTheme.success, closes: true)
                }
            case .failed(let release, let message):
                card { failure(release, message) }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: updater.state)
    }

    private func available(_ release: Release) -> some View {
        let installsHere = updater.canInstall && release.archive != nil
        return VStack(alignment: .leading, spacing: 12) {
            note("TimeTracker \(release.version) is available",
                 detail: updater.currentVersion.map { "You have \($0)." },
                 symbol: "arrow.down.circle.fill", color: AppTheme.accent, closes: true)
            HStack(spacing: 10) {
                Button {
                    Task { await updater.install(release) }
                } label: {
                    actionLabel(installsHere ? "Install Update" : "Download", prominent: true)
                }
                .buttonStyle(.glassCapsule(tint: AppTheme.accent.opacity(0.92)))

                Button("What’s New") { updater.openPage(of: release) }
                    .buttonStyle(.link)
                    .font(.system(size: 12, weight: .medium))
            }
            .glassGroup(spacing: 10)
            if !updater.canInstall {
                Text("Move TimeTracker to Applications to install updates from here.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func failure(_ release: Release?, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            note("Couldn’t update TimeTracker", detail: message,
                 symbol: "exclamationmark.triangle.fill", color: AppTheme.accentWarm, closes: true)
            if let release {
                HStack(spacing: 10) {
                    Button {
                        Task { await updater.install(release) }
                    } label: {
                        actionLabel("Try Again", prominent: false)
                    }
                    .buttonStyle(.glassCapsule())

                    Button("Download") { updater.openPage(of: release) }
                        .buttonStyle(.link)
                        .font(.system(size: 12, weight: .medium))
                }
            }
        }
    }

    private func actionLabel(_ title: String, prominent: Bool) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(prominent ? AppTheme.onAccent : AppTheme.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: 28)
    }

    private func note(_ title: String, detail: String?, symbol: String, color: Color, closes: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if closes {
                Button { updater.dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.glassCircle())
                .help("Hide")
            }
        }
    }

    private func progress(_ title: String, detail: String? = nil) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(14)
            .frame(width: 340, alignment: .leading)
            .glassSurface(in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge + 2, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
            .padding(AppTheme.spacingMD)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// TimeTracker › Check for Updates…, and whether to check by itself.
struct UpdateCommands: Commands {
    @ObservedObject var updater: Updater

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                Task { await updater.check(userInitiated: true) }
            }
            .disabled(updater.isBusy)
            Toggle("Check for Updates Automatically", isOn: $updater.checksAutomatically)
        }
    }
}
