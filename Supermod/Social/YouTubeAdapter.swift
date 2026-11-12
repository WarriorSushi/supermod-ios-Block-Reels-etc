import Foundation

struct YouTubeAdapter: PlatformAdapter {
    let name = "YouTube"
    let entry = URL(string: "https://m.youtube.com/")!
    let signInURL = URL(string: "https://www.youtube.com/signin")!
    let hosts: Set<String> = ["youtube.com", "www.youtube.com", "m.youtube.com", "consent.youtube.com"]
    let filterEngine = FilterScripts.Engine.youtube

    func decision(for url: URL, hidden: Set<Mod>) -> RouteDecision {
        guard owns(url) else {
            return ["http", "https"].contains(url.scheme?.lowercased() ?? "") ? .external : .unsupported
        }
        if url.host == "consent.youtube.com" { return .authentication }
        let section = url.path.split(separator: "/").first?.lowercased()
        if section == "shorts", hidden.contains(.reels) { return .blocked(.reels) }
        return .allow
    }
}
