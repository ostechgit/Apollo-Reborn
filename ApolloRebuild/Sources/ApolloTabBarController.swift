import UIKit

// ApolloTabBarController - main tab bar controller for the app
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// The original's tab set, left to right (matches 1.15.11 on iOS 26): Posts,
// Inbox, <signed-in username>, Search, Settings. There is no separate Popular
// tab, and the middle tab is the signed-in user's profile titled with their
// username rather than the word "Profile" ("Profile" is only used signed out).
// Each tab root is a UINavigationController and each item's image is one of the
// catalog's five tab-bar-* assets; the original never uses SF Symbols here.
//
// The Home tab's root is RedditListViewController (the subreddit list), not a
// feed: tapping "Posts from subscriptions" opens the front page.
//
// The original also exposes goToHomeTab / goToInboxTab / goToProfileTab /
// goToSearchTab / goToSettingsTab (used by its tab-bar gestures and deep links),
// reproduced below.

class ApolloTabBarController: UITabBarController {

    /// The original's tab order; raw values are the indices its goTo*Tab
    /// methods select.
    enum Tab: Int, CaseIterable {
        case posts = 0
        case inbox = 1
        case profile = 2
        case search = 3
        case settings = 4
    }

    let postsViewController = RedditListViewController()
    let inboxViewController = InboxViewController()
    let searchViewController = SearchViewController()
    let settingsViewController = SettingsViewController()
    /// The profile tab's screen. Its title is the account username (or
    /// "Profile" when signed out, where Apollo shows its sign-in prompt).
    let profileViewController = ProfileViewController.forCurrentAccount()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tabBar.tintColor = ThemeManager.shared.accentColor()

        // The Posts tab's navigation stack matches the original: the subreddit
        // list is the stack's root (its nav bar holds "+", "Subreddits" and
        // "Edit") and the front-page feed is pushed on top of it, which is why
        // the feed has a back chevron in its nav bar. Apollo lands on the feed at
        // launch instead of on the list, so the feed is pushed immediately.
        let postsNavigation = self.navigationController(
            for: self.postsViewController, tab: .posts, title: "Posts")
        postsNavigation.pushViewController(PostsViewController(postsType: .frontPage), animated: false)

        self.viewControllers = [
            postsNavigation,
            self.navigationController(for: self.inboxViewController, tab: .inbox, title: "Inbox"),
            self.navigationController(for: self.profileViewController, tab: .profile),
            self.navigationController(for: self.searchViewController, tab: .search, title: "Search"),
            self.navigationController(for: self.settingsViewController, tab: .settings, title: "Settings")
        ]

        // Signing in or out renames the middle tab (the title is the username)
        // and reloads the profile it shows.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accountDidChange),
            name: AccountManager.accountDidChangeNotification,
            object: nil)
    }

    // MARK: - Tab construction

    private func navigationController(for root: UIViewController, tab: Tab, title: String? = nil) -> UINavigationController {
        let displayTitle: String
        if let title = title {
            displayTitle = title
        } else if tab == .profile, let username = AccountManager.shared.username {
            displayTitle = username
        } else if tab == .profile {
            displayTitle = "Profile"
        } else {
            displayTitle = ""
        }

        root.title = root.title?.isEmpty == false ? root.title : displayTitle
        root.tabBarItem = UITabBarItem(
            title: displayTitle,
            image: ApolloAssets.tabBarImage(named: ApolloTabBarController.assetName(for: tab)),
            tag: tab.rawValue)

        let navigation = UINavigationController(rootViewController: root)
        navigation.navigationBar.prefersLargeTitles = false
        return navigation
    }

    /// The catalog name of a tab's icon, in the original's naming scheme.
    static func assetName(for tab: Tab) -> String {
        switch tab {
        case .posts: return "tab-bar-posts"
        case .inbox: return "tab-bar-inbox"
        case .profile: return "tab-bar-profile"
        case .search: return "tab-bar-search"
        case .settings: return "tab-bar-settings"
        }
    }

    // MARK: - Account changes

    @objc private func accountDidChange() {
        guard let username = AccountManager.shared.username else {
            self.profileViewController.title = "Profile"
            self.profileViewController.tabBarItem.title = "Profile"
            return
        }
        self.profileViewController.title = username
        self.profileViewController.tabBarItem.title = username
    }

    // MARK: - Tabs selected programmatically (deep links, gestures)

    @objc func goToHomeTab() {
        self.selectedIndex = Tab.posts.rawValue
    }

    @objc func goToInboxTab() {
        self.selectedIndex = Tab.inbox.rawValue
    }

    @objc func goToProfileTab() {
        self.selectedIndex = Tab.profile.rawValue
    }

    @objc func goToSearchTab() {
        self.selectedIndex = Tab.search.rawValue
    }

    @objc func goToSettingsTab() {
        self.selectedIndex = Tab.settings.rawValue
    }
}
