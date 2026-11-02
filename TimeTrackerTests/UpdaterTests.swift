import AppKit
import CryptoKit
import XCTest
@testable import TimeTracker

final class AppVersionTests: XCTestCase {
    func testVersionsAndTagsAreRead() {
        XCTAssertEqual(AppVersion("0.4.0")?.numbers, [0, 4, 0])
        XCTAssertEqual(AppVersion("v1.10")?.numbers, [1, 10])
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("latest"))
        XCTAssertNil(AppVersion("1.x"))
        XCTAssertNil(AppVersion("1..2"))
    }

    func testVersionsCompareNumberByNumber() {
        XCTAssertLessThan(AppVersion("0.9.1")!, AppVersion("0.10.0")!)
        XCTAssertLessThan(AppVersion("0.4.0")!, AppVersion("v0.4.1")!)
        XCTAssertEqual(AppVersion("0.4")!, AppVersion("0.4.0")!)
        XCTAssertFalse(AppVersion("1.0")! < AppVersion("0.99")!)
    }
}

final class ReleaseTests: XCTestCase {
    func testTheZippedAppAndItsSignatureAreFound() throws {
        let release = try XCTUnwrap(Release(gitHubJSON: releaseJSON(tag: "v0.5.0")))
        XCTAssertEqual(release.version, AppVersion("0.5.0"))
        XCTAssertEqual(release.title, "TimeTracker 0.5.0")
        XCTAssertEqual(release.archive?.lastPathComponent, "TimeTracker.zip")
        XCTAssertEqual(release.signature?.lastPathComponent, "TimeTracker.zip.sig")
        XCTAssertEqual(release.page.absoluteString, "https://github.com/breidenbach0/time-tracker/releases/tag/v0.5.0")
    }

    func testAReleaseWithoutTheZipCanOnlyBeDownloadedFromItsPage() throws {
        let release = try XCTUnwrap(Release(gitHubJSON: releaseJSON(tag: "v0.5.0", assets: ["TimeTracker.dmg"])))
        XCTAssertNil(release.archive)
        XCTAssertNil(release.signature)
    }

    func testDraftsPrereleasesAndOddTagsAreIgnored() {
        XCTAssertNil(Release(gitHubJSON: releaseJSON(tag: "v0.5.0", draft: true)))
        XCTAssertNil(Release(gitHubJSON: releaseJSON(tag: "v0.5.0", prerelease: true)))
        XCTAssertNil(Release(gitHubJSON: releaseJSON(tag: "nightly")))
        XCTAssertNil(Release(gitHubJSON: Data("{}".utf8)))
    }

    func testTheBuiltInKeyIsTheReleaseKey() {
        XCTAssertEqual(UpdateSource.gitHub.signingKey.rawRepresentation.base64EncodedString(), UpdateSource.releaseKey)
    }
}

final class UpdateInstallerTests: XCTestCase {
    /// Stands in for the key in the developer's Keychain.
    private let key = Curve25519.Signing.PrivateKey()

    func testTheNewVersionTakesTheOldOnesPlace() throws {
        let (installed, archive) = try prepareUpdate(to: "0.5.0")
        try UpdateInstaller().install(archive: archive, signature: signature(of: archive, with: key), signedBy: key.publicKey,
                                      version: AppVersion("0.5.0")!, over: installed)
        XCTAssertEqual(version(of: installed), "0.5.0")
        XCTAssertNoThrow(try UpdateInstaller.run("/usr/bin/codesign", ["--verify", "--strict", installed.path]))
    }

    func testAnUpdateSignedWithAnotherKeyIsntInstalled() throws {
        let (installed, archive) = try prepareUpdate(to: "0.5.0")
        let someoneElse = Curve25519.Signing.PrivateKey()
        XCTAssertThrowsError(try UpdateInstaller().install(archive: archive, signature: signature(of: archive, with: someoneElse),
                                                           signedBy: key.publicKey, version: AppVersion("0.5.0")!, over: installed)) {
            XCTAssertEqual($0 as? UpdateInstaller.Failure, .notSigned)
        }
        XCTAssertEqual(version(of: installed), "0.4.0")
    }

    func testAnUpdateChangedAfterSigningIsntInstalled() throws {
        let (installed, archive) = try prepareUpdate(to: "0.5.0")
        let signed = try signature(of: archive, with: key)
        let handle = try FileHandle(forWritingTo: archive)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0]))
        try handle.close()
        XCTAssertThrowsError(try UpdateInstaller().install(archive: archive, signature: signed, signedBy: key.publicKey,
                                                           version: AppVersion("0.5.0")!, over: installed)) {
            XCTAssertEqual($0 as? UpdateInstaller.Failure, .notSigned)
        }
        XCTAssertEqual(version(of: installed), "0.4.0")
    }

    func testAnotherAppIsntInstalledInTimeTrackersPlace() throws {
        let (installed, archive) = try prepareUpdate(to: "0.5.0", bundleID: "com.example.other")
        XCTAssertThrowsError(try UpdateInstaller().install(archive: archive, signature: signature(of: archive, with: key),
                                                           signedBy: key.publicKey, version: AppVersion("0.5.0")!, over: installed)) {
            XCTAssertEqual($0 as? UpdateInstaller.Failure, .notTimeTracker)
        }
        XCTAssertEqual(version(of: installed), "0.4.0")
    }

    func testAnAppOfAnotherVersionThanTheReleaseIsntInstalled() throws {
        let (installed, archive) = try prepareUpdate(to: "0.4.0")
        XCTAssertThrowsError(try UpdateInstaller().install(archive: archive, signature: signature(of: archive, with: key),
                                                           signedBy: key.publicKey, version: AppVersion("0.5.0")!, over: installed)) {
            XCTAssertEqual($0 as? UpdateInstaller.Failure, .wrongVersion("0.4.0"))
        }
    }

    func testAnAppThatsReallyALinkToSomethingElseIsntInstalled() throws {
        let root = makeTemporaryDirectory()
        let installed = try makeApp(at: root.appendingPathComponent("Applications/TimeTracker.app"), version: "0.4.0")
        let elsewhere = try makeApp(at: root.appendingPathComponent("elsewhere/Other.app"), version: "0.5.0")
        let build = root.appendingPathComponent("build", isDirectory: true)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: build.appendingPathComponent("TimeTracker.app"), withDestinationURL: elsewhere)
        let archive = root.appendingPathComponent("TimeTracker.zip")
        try UpdateInstaller.run("/usr/bin/ditto", ["-c", "-k", "--keepParent", build.appendingPathComponent("TimeTracker.app").path, archive.path])
        XCTAssertThrowsError(try UpdateInstaller().install(archive: archive, signature: signature(of: archive, with: key),
                                                           signedBy: key.publicKey, version: AppVersion("0.5.0")!, over: installed)) {
            XCTAssertEqual($0 as? UpdateInstaller.Failure, .notTimeTracker)
        }
        XCTAssertEqual(version(of: installed), "0.4.0")
    }

    func testLoosePermissionsInTheDownloadArentInstalled() throws {
        let root = makeTemporaryDirectory()
        let installed = try makeApp(at: root.appendingPathComponent("Applications/TimeTracker.app"), version: "0.4.0")
        let build = try makeApp(at: root.appendingPathComponent("build/TimeTracker.app"), version: "0.5.0")
        let program = build.appendingPathComponent("Contents/MacOS/TimeTracker")
        try FileManager.default.setAttributes([.posixPermissions: 0o6777], ofItemAtPath: program.path)
        let archive = root.appendingPathComponent("TimeTracker.zip")
        try UpdateInstaller.run("/usr/bin/ditto", ["-c", "-k", "--keepParent", build.path, archive.path])

        try UpdateInstaller().install(archive: archive, signature: signature(of: archive, with: key), signedBy: key.publicKey,
                                      version: AppVersion("0.5.0")!, over: installed)
        let installedProgram = installed.appendingPathComponent("Contents/MacOS/TimeTracker")
        let mode = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: installedProgram.path)[.posixPermissions] as? Int)
        XCTAssertEqual(mode & 0o7777, 0o755, "no setuid or setgid, and only the owner may write")
    }

    func testOnlyAddressesBelowTheReleasesAreTrusted() {
        let source = UpdateSource.gitHub
        let base = "https://github.com/breidenbach0/time-tracker/releases/download/v0.5.0/TimeTracker.zip"
        XCTAssertTrue(source.allowsDownload(from: URL(string: base)!))
        XCTAssertFalse(source.allowsDownload(from: URL(string: "https://github.com/breidenbach0/time-tracker/releases/download/../../evil/x.zip")!))
        XCTAssertFalse(source.allowsDownload(from: URL(string: "https://github.com/breidenbach0/time-tracker/releases/download/%2E%2E/%2e%2e/evil/x.zip")!))
        XCTAssertFalse(source.allowsDownload(from: URL(string: "https://github.com.evil.example/breidenbach0/time-tracker/releases/download/x.zip")!))
        XCTAssertFalse(source.allowsDownload(from: URL(string: "http://github.com/breidenbach0/time-tracker/releases/download/x.zip")!))
        XCTAssertTrue(source.allowsPage(URL(string: "https://github.com/breidenbach0/time-tracker/releases/tag/v0.5.0")!))
        XCTAssertFalse(source.allowsPage(URL(string: "https://example.com/breidenbach0/time-tracker/")!))
    }
}

final class UpdaterTests: XCTestCase {
    /// Stands in for the key in the developer's Keychain.
    private let key = Curve25519.Signing.PrivateKey()

    @MainActor
    func testANewerReleaseIsFoundInstalledAndStarted() async throws {
        let (installed, archive) = try prepareUpdate(to: "0.5.0")
        let defaults = makeDefaults()
        var started: URL?
        let updater = Updater(source: try makeFeed(offering: archive, as: "v0.5.0", signedWith: key), app: installed,
                              currentVersion: AppVersion("0.4.0"), defaults: defaults,
                              relaunch: { started = $0; return true })

        await updater.check(userInitiated: false)
        guard case .available(let release) = updater.state else { return XCTFail("no update offered: \(updater.state)") }
        XCTAssertEqual(release.version, AppVersion("0.5.0"))

        await updater.install(release)
        XCTAssertEqual(version(of: installed), "0.5.0")
        XCTAssertEqual(started, installed)
        XCTAssertEqual(defaults.string(forKey: Updater.updatedToKey), "0.5.0", "the new copy says it was updated")
    }

    @MainActor
    func testNothingIsOfferedWhenTimeTrackerIsUpToDate() async throws {
        let (installed, archive) = try prepareUpdate(to: "0.4.0")
        let updater = Updater(source: try makeFeed(offering: archive, as: "v0.4.0", signedWith: key), app: installed,
                              currentVersion: AppVersion("0.4.0"), defaults: makeDefaults(), relaunch: { _ in true })
        await updater.check(userInitiated: true)
        XCTAssertEqual(updater.state, .idle)
        XCTAssertTrue(updater.isShowingUpToDate)
    }

    @MainActor
    func testUnsignedUpdatesAndUpdatesSignedWithAnotherKeyArentInstalled() async throws {
        for signer in [nil, Curve25519.Signing.PrivateKey()] {
            let (installed, archive) = try prepareUpdate(to: "0.5.0")
            let updater = Updater(source: try makeFeed(offering: archive, as: "v0.5.0", signedWith: signer), app: installed,
                                  currentVersion: AppVersion("0.4.0"), defaults: makeDefaults(),
                                  relaunch: { _ in XCTFail("started"); return true })
            await updater.check(userInitiated: false)
            guard case .available(let release) = updater.state else { return XCTFail("no update offered") }
            await updater.install(release)
            guard case .failed = updater.state else { return XCTFail("installed anyway: \(updater.state)") }
            XCTAssertEqual(version(of: installed), "0.4.0")
        }
    }

    @MainActor
    func testUpdatesFromAnywhereButTheReleasesArentDownloaded() async throws {
        let (installed, archive) = try prepareUpdate(to: "0.5.0")
        let feed = try makeFeed(offering: archive, as: "v0.5.0", signedWith: key)
        let source = UpdateSource(latestRelease: feed.latestRelease, downloadPrefix: UpdateSource.gitHub.downloadPrefix,
                                  signingKey: key.publicKey)
        let updater = Updater(source: source, app: installed, currentVersion: AppVersion("0.4.0"),
                              defaults: makeDefaults(), relaunch: { _ in XCTFail("started"); return true })
        await updater.check(userInitiated: false)
        guard case .available(let release) = updater.state else { return XCTFail("no update offered") }
        await updater.install(release)
        guard case .failed = updater.state else { return XCTFail("installed from elsewhere: \(updater.state)") }
        XCTAssertEqual(version(of: installed), "0.4.0")
    }

    @MainActor
    func testTheNewVersionSaysItWasUpdatedAfterItStarts() {
        let defaults = makeDefaults()
        defaults.set("1.2.0", forKey: Updater.updatedToKey)
        let updater = Updater(currentVersion: AppVersion("1.2.0"), defaults: defaults, relaunch: { _ in true })
        updater.finishUpdate()
        XCTAssertEqual(updater.state, .updated(AppVersion("1.2.0")!))
        XCTAssertNil(defaults.string(forKey: Updater.updatedToKey))
    }

    @MainActor
    func testAnInterruptedUpdateDoesntClaimToHaveWorked() {
        let defaults = makeDefaults()
        defaults.set("1.2.0", forKey: Updater.updatedToKey)
        let updater = Updater(currentVersion: AppVersion("1.1.0"), defaults: defaults, relaunch: { _ in true })
        updater.finishUpdate()
        XCTAssertEqual(updater.state, .idle)
    }

    func testTheNewCopyStartsOnlyOnceTheOldOneHasQuit() throws {
        let marker = makeTemporaryDirectory().appendingPathComponent("started")
        let old = Process()
        old.executableURL = URL(fileURLWithPath: "/bin/sleep")
        old.arguments = ["0.6"]
        try old.run()
        let start = Date()

        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", Updater.relaunchScript, "sh", String(old.processIdentifier), "/usr/bin/touch", marker.path]
        try relaunch.run()
        relaunch.waitUntilExit()

        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        XCTAssertGreaterThan(Date().timeIntervalSince(start), 0.4)
    }

    /// A stand-in for GitHub: a local file answering "latest release" with `archive` as `tag`,
    /// signed by `signer` if there is one, and its folder as the only place to download from.
    /// Updates must be signed with this test's key.
    private func makeFeed(offering archive: URL, as tag: String, signedWith signer: Curve25519.Signing.PrivateKey?) throws -> UpdateSource {
        let directory = archive.deletingLastPathComponent()
        var assets = [#"{"name": "TimeTracker.zip", "browser_download_url": "\#(archive.absoluteString)"}"#]
        if let signer {
            let signatureFile = directory.appendingPathComponent("TimeTracker.zip.sig")
            try Data(signature(of: archive, with: signer).base64EncodedString().utf8).write(to: signatureFile)
            assets.append(#"{"name": "TimeTracker.zip.sig", "browser_download_url": "\#(signatureFile.absoluteString)"}"#)
        }
        let json = """
            {"tag_name": "\(tag)", "name": "TimeTracker", "draft": false, "prerelease": false,
             "html_url": "https://github.com/breidenbach0/time-tracker/releases/tag/\(tag)",
             "assets": [\(assets.joined(separator: ","))]}
            """
        let feed = directory.appendingPathComponent("latest.json")
        try Data(json.utf8).write(to: feed)
        return UpdateSource(latestRelease: feed, downloadPrefix: directory.absoluteString, signingKey: key.publicKey)
    }

    private func makeDefaults() -> UserDefaults {
        let name = "TimeTrackerUpdaterTests-\(UUID().uuidString)"
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return UserDefaults(suiteName: name)!
    }
}

extension XCTestCase {
    /// GitHub's answer about a release, cut down to what TimeTracker reads.
    func releaseJSON(tag: String, draft: Bool = false, prerelease: Bool = false,
                     assets: [String] = ["TimeTracker.dmg", "TimeTracker.zip", "TimeTracker.zip.sig"]) -> Data {
        let list = assets.map { name in
            """
            {"name": "\(name)", "size": 100, "digest": "sha256:ABC123", "content_type": "application/zip",
             "browser_download_url": "https://github.com/breidenbach0/time-tracker/releases/download/\(tag)/\(name)"}
            """
        }
        return Data("""
            {"tag_name": "\(tag)", "name": "TimeTracker 0.5.0", "draft": \(draft), "prerelease": \(prerelease),
             "html_url": "https://github.com/breidenbach0/time-tracker/releases/tag/\(tag)", "body": "Notes",
             "assets": [\(list.joined(separator: ","))]}
            """.utf8)
    }

    /// TimeTracker 0.4.0 installed in a temporary Applications folder, and a zipped TimeTracker
    /// `version` to update it with.
    func prepareUpdate(to version: String, bundleID: String = "com.simonbreidenbach.timetracker.TimeTracker") throws -> (installed: URL, archive: URL) {
        let root = makeTemporaryDirectory()
        let installed = try makeApp(at: root.appendingPathComponent("Applications/TimeTracker.app"), version: "0.4.0")
        let build = try makeApp(at: root.appendingPathComponent("build/TimeTracker.app"), version: version, bundleID: bundleID)
        let archive = root.appendingPathComponent("TimeTracker.zip")
        try UpdateInstaller.run("/usr/bin/ditto", ["-c", "-k", "--keepParent", build.path, archive.path])
        return (installed, archive)
    }

    /// The archive signed as sign-update signs releases.
    func signature(of archive: URL, with key: Curve25519.Signing.PrivateKey) throws -> Data {
        try key.signature(for: Data(contentsOf: archive))
    }

    /// A stand-in TimeTracker, signed, whose program is a copy of /usr/bin/true.
    @discardableResult
    func makeApp(at app: URL, version: String, bundleID: String = "com.simonbreidenbach.timetracker.TimeTracker") throws -> URL {
        let macOS = app.appendingPathComponent("Contents/MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: "/usr/bin/true", toPath: macOS.appendingPathComponent("TimeTracker").path)
        let info: [String: Any] = [
            "CFBundleExecutable": "TimeTracker",
            "CFBundleIdentifier": bundleID,
            "CFBundleName": "TimeTracker",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": version,
        ]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Contents/Info.plist"))
        try UpdateInstaller.run("/usr/bin/codesign", ["--force", "--sign", "-", app.path])
        return app
    }

    func version(of app: URL) -> String? {
        NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))?["CFBundleShortVersionString"] as? String
    }
}

extension XCTestCase {
    func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
