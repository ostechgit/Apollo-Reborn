import UIKit
import WebKit

// ExternalVideoSource - the third-party video hosts Apollo plays in-app.
//
// Apollo links YouTube through `YouTubePlayerController` and Streamable through
// an embed of its own; both are iframe players rather than media files, so the
// rebuild shows the post's preview image with a play badge and opens the embed
// in a web view instead of treating the link as an article card.
enum ExternalVideoSource: Equatable {
    case youtube(String)
    case streamable(String)
    case redgifs(String)

    init?(url: URL?) {
        guard let url = url, let host = url.host?.lowercased() else { return nil }
        let path = url.pathComponents.filter { $0 != "/" }

        func matches(_ domain: String) -> Bool {
            host == domain || host.hasSuffix("." + domain)
        }

        if matches("youtube.com") || matches("youtu.be") {
            // youtu.be/<id>, /watch?v=<id>, /embed/<id>, /shorts/<id>
            if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "v" })?.value, !id.isEmpty {
                self = .youtube(id)
                return
            }
            if let id = path.last, !id.isEmpty, path.count >= 1 {
                self = .youtube(id)
                return
            }
            return nil
        }

        if matches("streamable.com"), let id = path.last, !id.isEmpty {
            self = .streamable(id)
            return
        }

        // redgifs.com/watch/<id> and the gifs/detail/<id> idiom
        if matches("redgifs.com"), let id = path.last, !id.isEmpty {
            self = .redgifs(id)
            return
        }

        return nil
    }

    /// Embed URL the web view loads. YouTube needs `playsinline` so it behaves
    /// inside the sheet rather than trying to take over.
    var embedURL: URL? {
        switch self {
        case .youtube(let id):
            return URL(string: "https://www.youtube.com/embed/\(id)?playsinline=1&rel=0")
        case .streamable(let id):
            return URL(string: "https://streamable.com/e/\(id)")
        case .redgifs(let id):
            return URL(string: "https://www.redgifs.com/ifr/\(id)")
        }
    }

    var displayName: String {
        switch self {
        case .youtube: return "YouTube"
        case .streamable: return "Streamable"
        case .redgifs: return "RedGIFs"
        }
    }
}

// ExternalVideoViewController - a sheet that plays an embed full width.
final class ExternalVideoViewController: UIViewController {

    private let source: ExternalVideoSource
    private let webView = WKWebView()

    init(source: ExternalVideoSource) {
        self.source = source
        super.init(nibName: nil, bundle: nil)
        self.title = source.displayName
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black

        self.webView.backgroundColor = .black
        self.webView.isOpaque = false
        // Inline playback lives on the web view's configuration.
        let configuration = self.webView.configuration
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        self.webView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.webView)
        NSLayoutConstraint.activate([
            self.webView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.webView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.webView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            // 16:9 is the only aspect both hosts guarantee.
            self.webView.heightAnchor.constraint(equalTo: self.webView.widthAnchor, multiplier: 9.0 / 16.0)
        ])

        if let url = self.source.embedURL {
            self.webView.load(URLRequest(url: url))
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop playback when the sheet closes.
        self.webView.evaluateJavaScript("document.querySelectorAll('video').forEach(v => v.pause())",
                                        completionHandler: nil)
    }
}
