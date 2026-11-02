import Foundation
import UIKit

// ImgurAlbumResolver - opens an Imgur album or gallery as a pager.
//
// Apollo reads the reader's own Imgur client id (`ImgurApiClientId`, shared with
// the upload flow) and asks the Imgur API for the album's images:
//
//   GET https://api.imgur.com/3/album/<id>     Authorization: Client-ID <id>
//   GET https://api.imgur.com/3/gallery/<id>
//        -> { "data": { "images": [ { "link": "...", "type": "image/jpeg" } ] } }
//
// The shape follows the open-source Infinity for Reddit iOS client, which talks
// to the same API. With no client id configured the link keeps its normal
// behaviour instead of failing.
enum ImgurAlbumResolver {

    struct Album {
        let imageURLs: [URL]
    }

    static var clientID: String? {
        let value = UserDefaults.standard.string(forKey: "ImgurApiClientId") ?? ""
        return value.isEmpty ? nil : value
    }

    /// Extracts the album id from imgur.com/a/<id>, /gallery/<id> or /g/<id>.
    static func albumID(from url: URL?) -> String? {
        guard let url = url, let host = url.host?.lowercased(),
              host == "imgur.com" || host.hasSuffix(".imgur.com") else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2 else { return nil }
        switch parts[0] {
        case "a", "gallery", "g":
            let id = parts[1].components(separatedBy: ".")[0]
            return id.isEmpty ? nil : id
        default:
            return nil
        }
    }

    /// Fetches the album's images. Returns nil when the link is not an album, no
    /// client id is configured, or the request fails.
    static func resolve(_ url: URL?) async -> Album? {
        guard let id = albumID(from: url), let clientID = clientID,
              let requestURL = URL(string: "https://api.imgur.com/3/album/\(id)") else { return nil }
        var request = URLRequest(url: requestURL)
        request.setValue("Client-ID \(clientID)", forHTTPHeaderField: "Authorization")

        var data: Data?
        if let (body, response) = try? await URLSession.shared.data(for: request),
           (response as? HTTPURLResponse)?.statusCode == 200 {
            data = body
        } else {
            // Galleries live at a different path than plain albums.
            guard let galleryURL = URL(string: "https://api.imgur.com/3/gallery/\(id)") else { return nil }
            var galleryRequest = URLRequest(url: galleryURL)
            galleryRequest.setValue("Client-ID \(clientID)", forHTTPHeaderField: "Authorization")
            if let (body, response) = try? await URLSession.shared.data(for: galleryRequest),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                data = body
            }
        }

        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = json["data"] as? [String: Any],
              let images = payload["images"] as? [[String: Any]] else { return nil }

        let urls = images.compactMap { image -> URL? in
            guard let link = image["link"] as? String,
                  let type = image["type"] as? String,
                  type.hasPrefix("image/") || type == "video/mp4" else { return nil }
            return URL(string: link)
        }
        return urls.isEmpty ? nil : Album(imageURLs: urls)
    }

    /// Presents the album, or reports that it could not be opened.
    static func present(from viewController: UIViewController, url: URL?) {
        Task {
            let album = await resolve(url)
            await MainActor.run {
                guard let album = album else {
                    let alert = UIAlertController(title: "Couldn't Open Album",
                        message: "Add your Imgur client ID in settings to view albums in the app.",
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    viewController.present(alert, animated: true)
                    return
                }
                let pager = MediaPageViewController(mediaURLs: album.imageURLs)
                let navigation = UINavigationController(rootViewController: pager)
                pager.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done,
                    primaryAction: UIAction { [weak navigation] _ in navigation?.dismiss(animated: true) })
                viewController.present(navigation, animated: true)
            }
        }
    }
}
