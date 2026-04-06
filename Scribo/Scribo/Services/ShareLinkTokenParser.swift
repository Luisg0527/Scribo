import Foundation

/// Payloads we recognize from a QR scan, deep link, or pasted Scribo URL.
enum ScriboSharedLink: Equatable {
    /// Legacy: single note (`get_note_by_share_token`). Path `/n/{token}`.
    case noteShare(token: UUID)
    /// Whole notebook / topic tree (`get_notebook_by_share_token`). Path `/b/{token}`.
    case notebookShare(token: UUID)
    /// Same-account convenience only (`/invite/topic/{topicId}`) — not a public share token.
    case topicInvite(topicId: UUID)
}

/// Parses Scribo share URLs (HTTPS + custom scheme) into share payloads.
enum ShareLinkTokenParser {
    static func sharedLink(fromScannedRaw raw: String) -> ScriboSharedLink? {
        let normalized = normalizeScannedPayload(raw)
        guard !normalized.isEmpty else { return nil }
        if let url = URL(string: normalized), let link = sharedLink(from: url) { return link }
        if let comps = URLComponents(string: normalized), let link = sharedLink(from: comps) { return link }
        if !normalized.contains("://"), let url = URL(string: "https://\(normalized)"), let link = sharedLink(from: url) { return link }
        return nil
    }

    static func sharedLink(from url: URL) -> ScriboSharedLink? {
        sharedLink(from: URLComponents(url: url, resolvingAgainstBaseURL: false))
    }

    /// Legacy helpers — **note-only** (`/n/…` and `scribo://share?token=…`).
    static func token(fromScannedRaw raw: String) -> UUID? {
        if case let .noteShare(token) = sharedLink(fromScannedRaw: raw) { return token }
        return nil
    }

    static func token(from url: URL) -> UUID? {
        if case let .noteShare(token) = sharedLink(from: url) { return token }
        return nil
    }

    private static func sharedLink(from components: URLComponents?) -> ScriboSharedLink? {
        guard let components else { return nil }
        let scheme = components.scheme?.lowercased()
        if scheme == "http" || scheme == "https" {
            return parseHTTPScribo(components)
        }
        if scheme == "scribo" {
            return parseCustomScriboScheme(components)
        }
        return nil
    }

    private static func parseHTTPScribo(_ c: URLComponents) -> ScriboSharedLink? {
        guard let host = c.host?.lowercased(),
              host == "scribo.app" || host.hasSuffix(".scribo.app") else { return nil }
        let parts = c.path.split(separator: "/").map(String.init).filter { !$0.isEmpty }
        if parts.count >= 2, parts[0].lowercased() == "n", let u = UUID(uuidString: parts[1]) {
            return .noteShare(token: u)
        }
        if parts.count >= 2, parts[0].lowercased() == "b", let u = UUID(uuidString: parts[1]) {
            return .notebookShare(token: u)
        }
        if parts.count >= 3,
           parts[0].lowercased() == "invite",
           parts[1].lowercased() == "topic",
           let u = UUID(uuidString: parts[2]) {
            return .topicInvite(topicId: u)
        }
        return nil
    }

    private static func parseCustomScriboScheme(_ c: URLComponents) -> ScriboSharedLink? {
        let host = c.host?.lowercased()
        if host == "notebook" {
            if let items = c.queryItems,
               let raw = items.first(where: { $0.name.lowercased() == "token" })?.value,
               let u = UUID(uuidString: raw) {
                return .notebookShare(token: u)
            }
            return nil
        }
        if host == "share" || host == nil || host?.isEmpty == true {
            if let items = c.queryItems,
               let raw = items.first(where: { $0.name.lowercased() == "token" })?.value,
               let u = UUID(uuidString: raw) {
                return .noteShare(token: u)
            }
            let pathParts = c.path.split(separator: "/").map(String.init).filter { !$0.isEmpty }
            if let last = pathParts.last, let u = UUID(uuidString: last) {
                return .noteShare(token: u)
            }
        }
        return nil
    }

    private static func normalizeScannedPayload(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "\u{FEFF}", with: "")
        s = s.replacingOccurrences(of: "\u{200B}", with: "")
        s = s.replacingOccurrences(of: "\u{200C}", with: "")
        s = s.replacingOccurrences(of: "\u{200D}", with: "")
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return s
    }
}
