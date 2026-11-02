// Signs TimeTracker updates with the release key kept in your login Keychain, so TimeTracker's
// updater can tell an update really comes from you, and not just from whoever controls the
// GitHub release. The key never leaves the Keychain, and macOS asks you each time it's used.
//
// Usage (scripts/package-macos-dmg.sh does the signing):
//   swiftc -O scripts/sign-update.swift -o build/sign-update
//   build/sign-update --create-key                              once: makes the key and prints
//                                                               its public half for Updater.swift
//   build/sign-update dist/TimeTracker.zip > TimeTracker.zip.sig signs, as base64
import CryptoKit
import Foundation
import Security

let service = "com.simonbreidenbach.timetracker.update-signing"
let account = "TimeTracker releases"
let updaterSource = "TimeTracker/Services/Updater.swift"

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("sign-update: \(message)\n".utf8))
    exit(1)
}

func describe(_ status: OSStatus) -> String {
    SecCopyErrorMessageString(status, nil) as String? ?? "error \(status)"
}

/// Whether the Keychain has the key. Only asks about the item, so macOS doesn't prompt.
func keyExists() -> Bool {
    let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                                  kSecAttrAccount: account, kSecReturnAttributes: true]
    return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
}

func createKey() {
    guard !keyExists() else {
        fail("there's already a TimeTracker signing key in your Keychain. Released copies of TimeTracker only accept updates signed with it, so it isn't replaced.")
    }
    let key = Curve25519.Signing.PrivateKey()
    // No app is trusted with it, so macOS asks you every time anything wants the key.
    var access: SecAccess?
    let created = SecAccessCreate("TimeTracker update signing key" as CFString, [] as CFArray, &access)
    guard created == errSecSuccess, let access else { fail("couldn't set who may use the key: \(describe(created))") }
    let item: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account,
        kSecAttrLabel: "TimeTracker update signing key",
        kSecAttrDescription: "Ed25519 private key for signing TimeTracker updates",
        kSecValueData: key.rawRepresentation, kSecAttrAccess: access,
    ]
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else { fail("couldn't save the key in your Keychain: \(describe(status))") }
    print(key.publicKey.rawRepresentation.base64EncodedString())
}

func sign(_ path: String) {
    let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                                  kSecAttrAccount: account, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status != errSecItemNotFound else { fail("no TimeTracker signing key in your Keychain; make one with --create-key") }
    guard status == errSecSuccess, let raw = result as? Data else { fail("couldn't use the signing key: \(describe(status))") }
    guard let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else { fail("the key in your Keychain isn't a signing key") }

    // A signature only helps if the app checks it against this key.
    let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
    guard let source = try? String(contentsOfFile: updaterSource, encoding: .utf8), source.contains(publicKey) else {
        fail("this key's public half (\(publicKey)) isn't the one in \(updaterSource), so TimeTracker would refuse the update")
    }
    guard let data = FileManager.default.contents(atPath: path) else { fail("can't read \(path)") }
    guard let signature = try? key.signature(for: data), key.publicKey.isValidSignature(signature, for: data) else {
        fail("couldn't sign \(path)")
    }
    print(signature.base64EncodedString())
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments {
case ["--create-key"]:
    createKey()
case let files where files.count == 1:
    sign(files[0])
default:
    fail("usage: sign-update --create-key | sign-update <file>")
}
