import Foundation

/// Award icons Apollo draws beside a score, read from Reddit's all_awardings.
enum AwardIcons {
    static func urls(from awardings: [Any]?, limit: Int) -> [URL] {
        guard let awardings = awardings else { return [] }
        var urls: [URL] = []
        for case let award as [String: Any] in awardings {
            guard let value = award["icon_url"] as? String, let url = URL(string: value) else { continue }
            urls.append(url)
            if urls.count >= limit { break }
        }
        return urls
    }
}
