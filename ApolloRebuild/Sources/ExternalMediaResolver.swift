import AVFoundation
import AVKit
import Foundation
import UIKit

// ExternalMediaResolver - turns a third-party video link into something playable.
//
// Response shapes were taken from the open-source Infinity for Reddit iOS client
// (MIT), which talks to the same services:
//
//   RedGIFs   GET https://api.redgifs.com/v2/auth/temporary        -> { "token": "..." }
//             GET https://api.redgifs.com/v2/gifs/<id>             -> { "gif": { "urls": { "hd": "...", "sd": "..." } } }
//             (Authorization: bearer <token>)
//   Streamable GET https://api.streamable.com/videos/<code>        -> { "files": { "mp4": { "url": "..." }, "mp4-mobile": { ... } } }
//
// Both resolve to a plain MP4, which plays in AVPlayer without a web view. When a
// service fails, Streamable still has its iframe embed as a fallback.
enum ExternalMediaResolver {

    private static let userAgent = "Apollo/1.15.11 (rebuild)"
    private static var redgifsToken: String?

    /// Resolves a direct MP4 URL, or nil when the host has no such API.
    static func resolve(_ source: ExternalVideoSource) async -> URL? {
        switch source {
        case .redgifs(let id):
            return await redgifsURL(id: id)
        case .streamable(let code):
            return await streamableURL(code: code)
        case .youtube:
            // YouTube has no unauthenticated MP4 endpoint; it stays an embed.
            return nil
        }
    }

    // MARK: RedGIFs

    private static func redgifsURL(id: String) async -> URL? {
        guard let token = await redgifsAccessToken() else { return nil }
        guard let url = URL(string: "https://api.redgifs.com/v2/gifs/\(id)?user-agent=\(userAgent.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let gif = json["gif"] as? [String: Any],
              let urls = gif["urls"] as? [String: Any] else { return nil }

        // HD first, then SD, mirroring the reference client.
        for key in ["hd", "sd"] {
            if let value = urls[key] as? String, let url = URL(string: value) { return url }
        }
        return nil
    }

    private static func redgifsAccessToken() async -> String? {
        // Temporary tokens last long enough to reuse for a session.
        if let token = redgifsToken { return token }
        guard let url = URL(string: "https://api.redgifs.com/v2/auth/temporary") else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String else { return nil }
        redgifsToken = token
        return token
    }

    // MARK: Streamable

    private static func streamableURL(code: String) async -> URL? {
        guard let url = URL(string: "https://api.streamable.com/videos/\(code)") else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = json["files"] as? [String: Any] else { return nil }

        for key in ["mp4", "mp4-mobile"] {
            if let file = files[key] as? [String: Any],
               let value = file["url"] as? String, let url = URL(string: value) {
                return url
            }
        }
        return nil
    }

    // MARK: Presentation

    /// Plays the resolved MP4, or falls back to an iframe embed for hosts that
    /// only offer one.
    static func present(from viewController: UIViewController, source: ExternalVideoSource) {
        Task {
            let directURL = await resolve(source)
            await MainActor.run {
                if let directURL = directURL {
                    let player = AVPlayerViewController()
                    player.player = AVPlayer(url: directURL)
                    viewController.present(player, animated: true) { player.player?.play() }
                } else {
                    let embed = ExternalVideoViewController(source: source)
                    let navigation = UINavigationController(rootViewController: embed)
                    embed.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done,
                        primaryAction: UIAction { [weak navigation] _ in navigation?.dismiss(animated: true) })
                    viewController.present(navigation, animated: true)
                }
            }
        }
    }
}
