import Foundation

struct FacebookAdapter: PlatformAdapter {
    let name = "Facebook"
    let entry = URL(string: "https://www.facebook.com/?locale=en_US")!
    let signInURL = URL(string: "https://www.facebook.com/login/?locale=en_US")!
    let hosts: Set<String> = ["facebook.com", "www.facebook.com", "m.facebook.com"]
    let filterEngine = FilterScripts.Engine.facebook

    func decision(for url: URL, hidden: Set<Mod>) -> RouteDecision {
        guard owns(url) else { return ["http", "https"].contains(url.scheme?.lowercased() ?? "") ? .external : .unsupported }
        switch url.path.lowercased().split(separator: "/").first {
        case "login", "login.php", "checkpoint", "recover", "reg", "consent", "two_factor", "challenge":
            return .authentication
        case "reel", "reels":
            return hidden.contains(.reels) ? .blocked(.reels) : .allow
        case "stories" where hidden.contains(.stories):
            return .blocked(.stories)
        default:
            return .allow
        }
    }
}
