import Foundation

enum RouteDecision: Equatable {
    case allow, authentication, blocked(Mod), external, unsupported
}

protocol PlatformAdapter {
    var name: String { get }
    var entry: URL { get }
    var signInURL: URL { get }
    var hosts: Set<String> { get }
    var filterEngine: FilterScripts.Engine { get }
    func owns(_ url: URL) -> Bool
    func decision(for url: URL, hidden: Set<Mod>) -> RouteDecision
}

extension PlatformAdapter {
    func owns(_ url: URL) -> Bool {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "https", parts.port == nil || parts.port == 443,
              parts.user == nil, parts.password == nil, let host = parts.host?.lowercased()
        else { return false }
        return hosts.contains(host)
    }
}

struct InstagramAdapter: PlatformAdapter {
    let name = "Instagram"
    let entry = URL(string: "https://www.instagram.com/")!
    let signInURL = URL(string: "https://www.instagram.com/accounts/login/")!
    let hosts: Set<String> = ["instagram.com", "www.instagram.com", "m.instagram.com"]
    let filterEngine = FilterScripts.Engine.instagram

    func decision(for url: URL, hidden: Set<Mod>) -> RouteDecision {
        guard owns(url) else { return ["http", "https"].contains(url.scheme?.lowercased() ?? "") ? .external : .unsupported }
        let segments = url.path.split(separator: "/").map { $0.lowercased() }
        switch segments.first {
        case "accounts", "challenge", "checkpoint", "consent", "oauth", "privacy", "two_factor":
            return .authentication
        case "reel", "reels":
            return hidden.contains(.reels) ? .blocked(.reels) : .allow
        case "explore" where hidden.contains(.explore):
            return .blocked(.explore)
        case "stories" where hidden.contains(.stories):
            return .blocked(.stories)
        default:
            return .allow
        }
    }
}
