import AppKit
import CryptoKit
import OSLog

/// A version like 1.1.0, compared number by number, so 1.10 comes after 1.9.
struct AppVersion: Comparable, CustomStringConvertible, Sendable {
    let numbers: [Int]

    /// Reads "1.1.0", or a tag like "v1.1.0". Nil for anything else.
    init?(_ string: String) {
        let trimmed = string.hasPrefix("v") ? String(string.dropFirst()) : string
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap { part in part.allSatisfy(\.isASCII) ? Int(part) : nil }
        guard !parts.isEmpty, numbers.count == parts.count, numbers.allSatisfy({ $0 >= 0 }) else { return nil }
        self.numbers = numbers
    }

    /// The running app's version, from its Info.plist.
    static var current: AppVersion? {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init)
    }

    static func < (a: AppVersion, b: AppVersion) -> Bool {
        for index in 0..<max(a.numbers.count, b.numbers.count) {
            let x = index < a.numbers.count ? a.numbers[index] : 0
            let y = index < b.numbers.count ? b.numbers[index] : 0
            if x != y { return x < y }
        }
        return false
    }

    /// 1.1 and 1.1.0 are the same version.
    static func == (a: AppVersion, b: AppVersion) -> Bool { !(a < b) && !(b < a) }

    var description: String { numbers.map(String.init).joined(separator: ".") }
}

/// A TimeTracker release on GitHub.
struct Release: Equatable, Sendable {
    /// What the updater installs: the app, zipped, and its signature. Releases also carry
    /// TimeTracker.dmg, for people.
    static let archiveName = "TimeTracker.zip"
    static let signatureName = "TimeTracker.zip.sig"

    var version: AppVersion
    var title: String
    /// The release's page, with its notes and the disk image.
    var page: URL
    /// The zipped app. Nil for a release without one: it can only be downloaded from its page.
    var archive: URL?
    /// The archive's signature, made with the key in the developer's Keychain (scripts/sign-update.swift).
    var signature: URL?

    /// The release in GitHub's answer about the latest release. Nil for a draft, a prerelease,
    /// or a tag that isn't a version number.
    init?(gitHubJSON data: Data) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let payload = try? decoder.decode(Payload.self, from: data),
              payload.draft != true, payload.prerelease != true,
              let version = AppVersion(payload.tagName) else { return nil }
        self.version = version
        title = payload.name ?? "TimeTracker \(version)"
        page = payload.htmlUrl
        archive = payload.assets.first { $0.name == Self.archiveName }?.browserDownloadUrl
        signature = payload.assets.first { $0.name == Self.signatureName }?.browserDownloadUrl
    }

    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: URL
        }

        let tagName: String
        let name: String?
        let htmlUrl: URL
        let draft: Bool?
        let prerelease: Bool?
        let assets: [Asset]
    }
}

/// Where releases are looked up, and the only place updates are downloaded from.
struct UpdateSource {
    /// GitHub's API address for the latest release.
    var latestRelease: URL
    /// Updates are only downloaded from below this address…
    var downloadPrefix: String
    /// …and only release pages below this one are opened.
    var pagePrefix = "https://github.com/breidenbach0/time-tracker/"
    /// Updates must be signed with the private half of this key.
    var signingKey: Curve25519.Signing.PublicKey

    static let gitHub = UpdateSource(
        latestRelease: URL(string: "https://api.github.com/repos/breidenbach0/time-tracker/releases/latest")!,
        downloadPrefix: "https://github.com/breidenbach0/time-tracker/releases/download/",
        signingKey: try! Curve25519.Signing.PublicKey(rawRepresentation: Data(base64Encoded: releaseKey)!))

    /// The public half of the key TimeTracker's releases are signed with. The private half stays in
    /// the developer's Keychain, so getting into the GitHub account isn't enough to fake an update.
    static let releaseKey = "HiTRHmUemrO/ZupO0BuKax7PF5GkKkv031NtSzN+iT4="

    func allowsDownload(from url: URL) -> Bool { Self.isBelow(url, downloadPrefix) }

    func allowsPage(_ url: URL) -> Bool { Self.isBelow(url, pagePrefix) }

    /// Whether `url` starts with `prefix` and has no way back up out of it, however it's spelled.
    static func isBelow(_ url: URL, _ prefix: String) -> Bool {
        let text = url.absoluteString
        return text.hasPrefix(prefix) && !url.pathComponents.contains("..") && !text.lowercased().contains("%2e")
    }
}

/// Puts a downloaded TimeTracker in place of the one running.
struct UpdateInstaller {
    enum Failure: LocalizedError, Equatable {
        case damaged
        case notSigned
        case notTimeTracker
        case wrongVersion(String)
        case cantReplace(String)
        case tool(String)

        var errorDescription: String? {
            switch self {
            case .damaged:
                return "The download is damaged, or isn’t a TimeTracker update."
            case .notSigned:
                return "The update isn’t signed with TimeTracker’s key, so it wasn’t installed. You can download it from GitHub yourself instead."
            case .notTimeTracker:
                return "The download doesn’t contain TimeTracker."
            case .wrongVersion(let version):
                return "The download contains TimeTracker \(version), not the version the release is for."
            case .cantReplace(let message):
                return "Couldn’t replace TimeTracker: \(message) You can download the update from GitHub instead."
            case .tool(let message):
                return message
            }
        }
    }

    /// The TimeTracker app's bundle ID. An update must have the same.
    var bundleID = "com.simonbreidenbach.timetracker.TimeTracker"

    /// Far more than TimeTracker needs; anything bigger isn't a TimeTracker update.
    static let maxArchiveSize = 100_000_000

    /// Checks the zipped app was signed with `key` and unpacks it, leaving behind any attributes,
    /// access lists or loose permissions it might carry. Then checks the copy it's about to
    /// install is TimeTracker `version` with its code signature intact, and swaps it in for
    /// `app`. `app` stays as it was if anything fails.
    func install(archive: URL, signature: Data, signedBy key: Curve25519.Signing.PublicKey,
                 version: AppVersion, over app: URL) throws {
        let size = (try? archive.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard size <= Self.maxArchiveSize else { throw Failure.damaged }
        guard key.isValidSignature(signature, for: try Data(contentsOf: archive)) else { throw Failure.notSigned }

        let fileManager = FileManager.default
        let unpacked = fileManager.temporaryDirectory
            .appendingPathComponent("TimeTracker-update-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: unpacked) }
        // Unpacked as it was packed (ditto turns stored attributes back into attributes, not files),
        // then copied below without any of them.
        try Self.run("/usr/bin/ditto", ["-x", "-k", archive.path, unpacked.path])

        // The app itself, not a link to something else on the disk.
        let update = unpacked.appendingPathComponent("TimeTracker.app", isDirectory: true)
        let kind = try? update.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard kind?.isDirectory == true, kind?.isSymbolicLink == false else { throw Failure.notTimeTracker }

        // Copied next to the app first, so swapping it in is one quick step on the same disk.
        // That copy is what's checked, and then installed.
        let staging: URL
        do {
            staging = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                          appropriateFor: app, create: true)
        } catch {
            throw Failure.cantReplace(error.localizedDescription)
        }
        defer { try? fileManager.removeItem(at: staging) }
        let staged = staging.appendingPathComponent(app.lastPathComponent, isDirectory: true)
        try Self.run("/usr/bin/ditto", Self.plainCopy + [update.path, staged.path])
        // Only its owner may change it, and nothing in it runs as anyone else.
        try Self.run("/bin/chmod", ["-R", "go-w,ug-s", staged.path])
        try verify(staged, version: version)
        do {
            _ = try fileManager.replaceItemAt(app, withItemAt: staged, backupItemName: nil, options: .usingNewMetadataOnly)
        } catch {
            throw Failure.cantReplace(error.localizedDescription)
        }
    }

    /// Checks `app` is TimeTracker `version`, with its signature intact.
    private func verify(_ app: URL, version: AppVersion) throws {
        guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")) as? [String: Any],
              info["CFBundleIdentifier"] as? String == bundleID else { throw Failure.notTimeTracker }
        let shipped = info["CFBundleShortVersionString"] as? String ?? "?"
        guard AppVersion(shipped) == version else { throw Failure.wrongVersion(shipped) }
        try Self.run("/usr/bin/codesign", ["--verify", "--strict", app.path])
    }

    /// ditto options that copy files and nothing else: no extended attributes, quarantine or ACLs.
    private static let plainCopy = ["--norsrc", "--noextattr", "--noqtn", "--noacl"]

    static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Runs a command-line tool, and throws what it printed if it fails.
    static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        let message = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let text = String(decoding: message, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            let name = URL(fileURLWithPath: tool).lastPathComponent
            throw Failure.tool("\(name) failed: \(text.isEmpty ? "exit status \(process.terminationStatus)" : text)")
        }
    }
}

/// Looks for a newer TimeTracker on GitHub at launch and once a day, and installs it:
/// downloads it, swaps it in for this copy and starts it again.
@MainActor
final class Updater: ObservableObject {
    enum State: Equatable {
        /// Nothing to show.
        case idle
        /// Checking, because the user asked to.
        case checking
        case available(Release)
        case installing(Release, step: String)
        /// The new version is in place, but couldn't be started; opening TimeTracker again does it.
        case needsRestart(AppVersion)
        /// Started again after updating itself.
        case updated(AppVersion)
        case failed(Release?, String)
    }

    static let shared = Updater(relaunch: { app in
        // A running recording lives on in the saved timer state and resumes after the restart.
        TimerViewModel.shared.persistRunningTimerStateIfNeeded()
        return Updater.relaunch(app)
    })

    static let log = Logger(subsystem: "com.simonbreidenbach.timetracker", category: "updates")
    static let checksAutomaticallyKey = "TimeTrackerChecksForUpdates"
    static let lastCheckKey = "TimeTrackerLastUpdateCheck"
    /// Set just before starting the new version, so it can say it was updated.
    static let updatedToKey = "TimeTrackerUpdatedToVersion"

    @Published private(set) var state = State.idle
    /// A check the user asked for found nothing newer.
    @Published var isShowingUpToDate = false

    let currentVersion: AppVersion?
    let source: UpdateSource
    private let app: URL
    private let session: URLSession
    private let defaults: UserDefaults
    private let relaunch: @MainActor (URL) -> Bool
    private var timer: Timer?

    /// Keeps no cookies or cache, so update checks can't be told apart.
    nonisolated static let session = URLSession(configuration: .ephemeral)

    init(source: UpdateSource = .gitHub, app: URL = Bundle.main.bundleURL,
         currentVersion: AppVersion? = .current, session: URLSession = Updater.session,
         defaults: UserDefaults = .standard, relaunch: @escaping @MainActor (URL) -> Bool = Updater.relaunch(_:)) {
        self.source = source
        self.app = app
        self.currentVersion = currentVersion
        self.session = session
        self.defaults = defaults
        self.relaunch = relaunch
    }

    var checksAutomatically: Bool {
        get { defaults.object(forKey: Self.checksAutomaticallyKey) as? Bool ?? true }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: Self.checksAutomaticallyKey)
        }
    }

    /// Whether this copy can replace itself: an app in a folder it may write to, not one run
    /// from the disk image or from the read-only spot macOS moves quarantined apps to.
    var canInstall: Bool {
        app.pathExtension == "app"
            && !app.path.contains("/AppTranslocation/")
            && FileManager.default.isWritableFile(atPath: app.deletingLastPathComponent().path)
    }

    var isBusy: Bool {
        switch state {
        case .checking, .installing: return true
        default: return false
        }
    }

    /// Says so if this launch follows an update, then checks now unless that was done in the
    /// last hour, and once a day after that.
    func start() {
        guard timer == nil else { return }
        finishUpdate()
        checkIfDue(after: 3600)
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue(after: 24 * 3600) }
        }
        timer?.tolerance = 600
    }

    /// After TimeTracker updated itself and started again: shows that it worked.
    func finishUpdate() {
        guard let updatedTo = defaults.string(forKey: Self.updatedToKey) else { return }
        defaults.removeObject(forKey: Self.updatedToKey)
        guard let version = currentVersion, AppVersion(updatedTo) == version else { return }
        state = .updated(version)
    }

    private func checkIfDue(after interval: TimeInterval) {
        guard checksAutomatically, state == .idle else { return }
        let last = defaults.object(forKey: Self.lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= interval else { return }
        Task { await check(userInitiated: false) }
    }

    /// Looks for a newer release. A check the user asked for shows that it's checking, and says
    /// so when there's nothing newer or the check fails; other checks only show a newer release.
    func check(userInitiated: Bool) async {
        guard !isBusy else { return }
        if userInitiated { state = .checking }
        defaults.set(Date(), forKey: Self.lastCheckKey)
        do {
            if let release = try await latestRelease(), let current = currentVersion, release.version > current {
                Self.log.notice("TimeTracker \(release.version, privacy: .public) is available")
                state = .available(release)
            } else {
                if state == .checking { state = .idle }
                if userInitiated { isShowingUpToDate = true }
            }
        } catch {
            Self.log.error("checking for updates failed: \(error.localizedDescription)")
            if userInitiated {
                state = .failed(nil, "Couldn’t check for updates: \(error.localizedDescription)")
            }
        }
    }

    private func latestRelease() async throws -> Release? {
        var request = URLRequest(url: source.latestRelease, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { return nil }   // no release yet
            guard http.statusCode == 200 else { throw URLError(.badServerResponse) }
        }
        return Release(gitHubJSON: data)
    }

    /// Downloads the release, swaps it in for this copy of TimeTracker and starts it.
    func install(_ release: Release) async {
        guard !isBusy else { return }
        guard canInstall, let archive = release.archive else {
            openPage(of: release)
            return
        }
        guard let signature = release.signature else {
            state = .failed(release, UpdateInstaller.Failure.notSigned.localizedDescription)
            return
        }
        guard source.allowsDownload(from: archive), source.allowsDownload(from: signature) else {
            state = .failed(release, "The update isn’t where TimeTracker’s releases are, so it wasn’t downloaded.")
            return
        }
        state = .installing(release, step: "Downloading…")
        do {
            let signed = try await signatureData(from: signature)
            let (download, response) = try await session.download(from: archive)
            let file = FileManager.default.temporaryDirectory
                .appendingPathComponent("TimeTracker-\(release.version)-\(UUID().uuidString).zip")
            try FileManager.default.moveItem(at: download, to: file)
            defer { try? FileManager.default.removeItem(at: file) }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw URLError(.badServerResponse)
            }

            state = .installing(release, step: "Installing…")
            let (app, key) = (app, source.signingKey)
            try await Task.detached(priority: .userInitiated) {
                try UpdateInstaller().install(archive: file, signature: signed, signedBy: key, version: release.version, over: app)
            }.value
        } catch {
            Self.log.error("installing \(release.version, privacy: .public) failed: \(error.localizedDescription)")
            state = .failed(release, error.localizedDescription)
            return
        }

        Self.log.notice("installed TimeTracker \(release.version, privacy: .public); starting it")
        defaults.set(release.version.description, forKey: Self.updatedToKey)
        if !relaunch(app) { state = .needsRestart(release.version) }
    }

    /// A release's signature: base64 text, as sign-update writes it.
    private func signatureData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 { throw URLError(.badServerResponse) }
        let text = String(decoding: data.prefix(1024), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let signature = Data(base64Encoded: text) else { throw UpdateInstaller.Failure.notSigned }
        return signature
    }

    /// Opens the release's page, if it's one of TimeTracker's.
    func openPage(of release: Release) {
        guard source.allowsPage(release.page) else { return }
        NSWorkspace.shared.open(release.page)
    }

    /// Closes the card about an update, until the next check finds something.
    func dismiss() {
        if !isBusy { state = .idle }
    }

    /// Starts TimeTracker again from `app` once this copy has quit, and quits.
    /// Returns false, without quitting, if the new copy can't be started.
    static func relaunch(_ app: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", relaunchScript, "sh", String(ProcessInfo.processInfo.processIdentifier),
                             "/usr/bin/open", app.path]
        do {
            try process.run()
        } catch {
            log.error("couldn't start the new TimeTracker: \(error.localizedDescription)")
            return false
        }
        NSApp.terminate(nil)
        return true
    }

    /// Waits up to 20 seconds for process $1 to end, then runs $2 with $3.
    nonisolated static let relaunchScript = """
        i=0
        while /bin/kill -0 "$1" 2>/dev/null && [ "$i" -lt 100 ]; do /bin/sleep 0.2; i=$((i + 1)); done
        "$2" "$3"
        """
}
