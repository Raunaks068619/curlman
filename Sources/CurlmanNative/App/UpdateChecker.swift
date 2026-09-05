import Foundation

struct ReleaseVersion: Comparable, Equatable {
    let components: [Int]

    init?(_ rawValue: String) {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let numericPart = normalized.split(separator: "-", maxSplits: 1).first ?? ""
        let parsed = numericPart.split(separator: ".").map(String.init)
        guard !parsed.isEmpty,
              parsed.allSatisfy({ Int($0) != nil }) else {
            return nil
        }
        components = parsed.compactMap(Int.init)
    }

    static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    static func == (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

struct AvailableRelease: Equatable {
    let version: String
    let pageURL: URL
}

enum UpdateCheckResult: Equatable {
    case updateAvailable(AvailableRelease)
    case current
}

enum UpdateCheckerError: LocalizedError {
    case invalidResponse
    case invalidRelease

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GitHub returned an unexpected response."
        case .invalidRelease:
            return "The latest release has an invalid version or download page."
        }
    }
}

actor UpdateChecker {
    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    static let latestReleasePage = URL(string: "https://github.com/Raunaks068619/curlman/releases/latest")!
    static let latestReleaseAPI = URL(string: "https://api.github.com/repos/Raunaks068619/curlman/releases/latest")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func check(currentVersion: String) async throws -> UpdateCheckResult {
        var request = URLRequest(url: Self.latestReleaseAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Curlman/(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw UpdateCheckerError.invalidResponse
        }

        return try Self.evaluate(data: data, currentVersion: currentVersion)
    }

    static func evaluate(data: Data, currentVersion: String) throws -> UpdateCheckResult {
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard let current = ReleaseVersion(currentVersion),
              let latest = ReleaseVersion(release.tagName) else {
            throw UpdateCheckerError.invalidRelease
        }

        if latest > current {
            return .updateAvailable(AvailableRelease(version: release.tagName, pageURL: release.htmlURL))
        }
        return .current
    }
}
