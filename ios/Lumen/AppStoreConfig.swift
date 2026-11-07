import Foundation

/// Resolved submission settings. Placeholder values are intentional and unresolved.
/// A Release build must not be treated as App Store ready while `unresolved()` is non-empty.
enum AppStoreConfig {
    static let privacyURL = string("LumenPrivacyPolicyURL")
    static let termsURL = string("LumenTermsURL")
    static let supportURL = string("LumenSupportURL")
    static let teamID = string("LumenDevelopmentTeam")
    static let bundleID = Bundle.main.bundleIdentifier ?? ""

    static var blocksLaunch: Bool {
        string("LumenBlockOnPlaceholders") == "YES" && !unresolved().isEmpty
    }

    static func unresolved() -> [String] {
        var issues: [String] = []
        if invalidLink(privacyURL) { issues.append("Privacy policy URL is still a placeholder.") }
        if invalidLink(termsURL) { issues.append("Terms URL is still a placeholder.") }
        if invalidLink(supportURL) { issues.append("Support URL is still a placeholder.") }
        if isPlaceholder(teamID) { issues.append("Apple Developer Team ID is still REPLACE_ME.") }
        if bundleID.isEmpty || bundleID.contains("com.example") || isPlaceholder(bundleID) {
            issues.append("Bundle identifier still uses a placeholder.")
        }
        return issues
    }

    static func openableHTTPS(_ raw: String) -> URL? {
        guard !invalidLink(raw), let url = URL(string: raw), url.scheme == "https" else { return nil }
        return url
    }

    private static func string(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }

    private static func isPlaceholder(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty || value.contains("replace_me") || value.contains("example.com") || value.contains("com.example")
    }

    private static func invalidLink(_ raw: String) -> Bool {
        guard let url = URL(string: raw), url.scheme == "https", url.host != nil else { return true }
        return isPlaceholder(raw)
    }
}
