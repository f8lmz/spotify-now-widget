import Foundation
#if canImport(Security)
import Security
#endif

public enum AppGroupResolver {
    /// Keep this suffix identical to the entitlement in both targets:
    /// `$(TeamIdentifierPrefix)app.spotifynow`
    public static let groupSuffix = "app.spotifynow"

    public static func teamID(fromApplicationIdentifier identifier: String) -> String? {
        guard let first = identifier.split(separator: ".", omittingEmptySubsequences: false).first else {
            return nil
        }
        let team = String(first)
        guard team.count == 10 else { return nil }
        let allowed = CharacterSet.alphanumerics
        guard team.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return team
    }

    public static func groupIdentifier(teamID: String) -> String {
        "\(teamID).\(groupSuffix)"
    }

    public static func isUsableGroupIdentifier(_ identifier: String) -> Bool {
        let pieces = identifier.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard pieces.count == 2 else { return false }
        let team = String(pieces[0])
        guard team.count == 10 else { return false }
        let allowed = CharacterSet.alphanumerics
        guard team.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        return String(pieces[1]) == groupSuffix
    }

    public static func candidateGroupIdentifiers(entitlementGroups: [String], applicationIdentifier: String?) -> [String] {
        var result: [String] = []
        func append(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !result.contains(trimmed) else { return }
            result.append(trimmed)
        }
        entitlementGroups.forEach(append)
        if let applicationIdentifier, let team = teamID(fromApplicationIdentifier: applicationIdentifier) {
            append(groupIdentifier(teamID: team))
        }
        return result
    }

#if canImport(Security)
    /// Group ids actually signed into this process. macOS returns a container
    /// URL even for an id the app is not allowed to use, so callers must only
    /// try ids from this list and then check that the folder is writable.
    public static func entitledGroupIdentifiers() -> [String] {
        entitlementStrings("com.apple.security.application-groups")
    }

    public static func writableStoreURL() -> URL? {
        for id in entitledGroupIdentifiers() where isUsableGroupIdentifier(id) {
            guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) else {
                continue
            }
            let store = SharedLocation.storeDirectory(in: container)
            if DirectoryAccess.isWritable(store) {
                return store
            }
        }
        return nil
    }

    private static func entitlementStrings(_ key: String) -> [String] {
        guard let task = SecTaskCreateFromSelf(nil) else { return [] }
        guard let value = SecTaskCopyValueForEntitlement(task, key as CFString, nil) else { return [] }
        if let array = value as? [String] {
            return array
        }
        let nsArray = value as? NSArray
        return nsArray?.compactMap { $0 as? String } ?? []
    }
#endif
}
