import Foundation

struct BuildMetadata: Equatable, Sendable {
    let version: String
    let githubStars: Int

    init(bundle: Bundle = .main) {
        version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        githubStars = max(bundle.object(forInfoDictionaryKey: "CurlmanGitHubStars") as? Int ?? 0, 0)
    }
}

enum GitHubStarCopy {
    static func count(_ stars: Int) -> String {
        stars == 1 ? "1 star" : "\(stars) stars"
    }

    static func supporting(_ stars: Int) -> String {
        stars == 0 ? "Be the first star" : "Open source on GitHub"
    }
}
