import UIKit

// SceneDelegate - manages the app's scene lifecycle
// Reconstructed from apollo-base 1.15.11 binary analysis.

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        if let gallery = AssetGalleryViewController.galleryIfRequested() {
            // Development aid: shows what each Assets.car name actually draws
            window.rootViewController = UINavigationController(rootViewController: gallery)
        } else {
            window.rootViewController = ApolloTabBarController()
        }
        window.makeKeyAndVisible()
        self.window = window
        
        // Apply saved theme
        ThemeManager.shared.applyTheme()
        if let url = connectionOptions.urlContexts.first?.url ?? connectionOptions.userActivities.first?.webpageURL {
            self.openCommentURL(url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url { self.openCommentURL(url) }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if let url = userActivity.webpageURL { self.openCommentURL(url) }
    }

    private func openCommentURL(_ url: URL) {
        guard let tabs = self.window?.rootViewController as? ApolloTabBarController,
              let navigation = tabs.selectedViewController as? UINavigationController,
              let route = RedditCommentRoute(url: url),
              navigation.presentedViewController == nil else { return }
        route.push(on: navigation)
    }
}

/// Strict permalink parser shared by markdown and scene delivery. OS universal
/// link association is not configured here; no competing apollo scheme is added.
struct RedditCommentRoute {
    let postID: String
    let commentID: String?
    let context: Int?

    init?(url: URL) {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host?.lowercased(),
              ["reddit.com", "www.reddit.com", "old.reddit.com", "np.reddit.com", "m.reddit.com"].contains(host),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        let index: Int
        if parts.first == "comments" { index = 0 }
        else if parts.count >= 3, parts[0] == "r", parts[2] == "comments" { index = 2 }
        else { return nil }
        func validID(_ value: String) -> Bool {
            !value.isEmpty && value.unicodeScalars.allSatisfy {
                (48...57).contains($0.value) || (65...90).contains($0.value) || (97...122).contains($0.value)
            }
        }
        guard parts.count > index + 1, validID(parts[index + 1]), parts.count <= index + 4 else { return nil }
        self.postID = parts[index + 1]
        if parts.count == index + 4 {
            guard validID(parts[index + 3]) else { return nil }
            self.commentID = parts[index + 3]
        } else { self.commentID = nil }
        let contexts = components.queryItems?.filter { $0.name == "context" } ?? []
        guard contexts.count <= 1 else { return nil }
        if let item = contexts.first {
            guard let raw = item.value, let value = Int(raw), (0...100).contains(value) else { return nil }
            self.context = value
        } else { self.context = nil }
    }

    @discardableResult
    func push(on navigation: UINavigationController) -> Bool {
        guard let link = RDKLink(dictionary: ["id": self.postID, "name": "t3_" + self.postID]) else { return false }
        navigation.pushViewController(CommentsViewController(link: link, commentID: self.commentID, context: self.context), animated: true)
        return true
    }
}
