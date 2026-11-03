import AppKit
import SwiftUI

/// News about TimeTracker updates, floating at the bottom of the window: a check the user asked
/// for, what went wrong, or that an update worked. A newer version to install, and installing it,
/// show in the top bar instead (`UpdateButton`). Nothing when there's no news.
struct UpdateCard: View {
    @ObservedObject var updater: Updater

    var body: some View {
        Group {
            switch updater.state {
            case .idle, .available, .installing:
                EmptyView()
            case .checking:
                card { progress("Checking for updates…") }
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

    private func failure(_ release: Release?, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            note("Couldn’t update TimeTracker", detail: message,
                 symbol: "exclamationmark.triangle.fill", color: AppTheme.warning, closes: true)
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
            .font(.system(size: 12, weight: .semibold))
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
                    .font(.system(size: 13, weight: .semibold))
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
                    .font(.system(size: 13, weight: .medium))
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

/// Shows in the window's top bar while a newer TimeTracker is out: one click installs it and
/// restarts. While it installs, it shows how far along it is.
struct UpdateButton: View {
    @ObservedObject var updater: Updater
    var isCompact = false

    var body: some View {
        Group {
            switch updater.state {
            case .available(let release):
                let installsHere = updater.canInstall && release.archive != nil

                Button {
                    Task { await updater.install(release) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        if !isCompact {
                            Text(installsHere ? "Update to \(release.version)" : "Download \(release.version)")
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.onAccent)
                    .padding(.horizontal, isCompact ? 10 : 14)
                    .frame(height: 34)
                }
                .buttonStyle(.glassCapsule(tint: AppTheme.accent.opacity(0.92)))
                .help(installsHere
                      ? "Install TimeTracker \(release.version). It starts again when it’s done, and a running recording keeps going."
                      : "Download TimeTracker \(release.version) from GitHub. Move TimeTracker to Applications to install updates from here.")
                .contextMenu {
                    Button("What’s New") { updater.openPage(of: release) }
                    Button("Not Now") { updater.dismiss() }
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))

            case .installing(_, let step):
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    if !isCompact {
                        Text(step)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 34)
                .glassSurface(in: Capsule(style: .continuous))
                .help("TimeTracker starts again when it’s done. A running recording keeps going.")
                .transition(.opacity)

            default:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: updater.state)
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
