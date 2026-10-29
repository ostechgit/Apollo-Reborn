import UIKit

// ApolloTabBarController - main tab bar controller for the app
// Reconstructed from apollo-base 1.15.11 binary analysis.
// Original tabs: Home, Search, Inbox, Profile, Settings (no Popular tab).
// Home tab root is the subreddit list (RedditListViewController), not a feed.

class ApolloTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Home tab: subreddit list as root (original Apollo behavior)
        // Tapping "Posts from subscriptions" row 0 shows the front page feed
        let homeVC = RedditListViewController()
        homeVC.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)
        homeVC.title = "Home"
        
        // Search tab
        let searchVC = SearchViewController()
        searchVC.tabBarItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), tag: 1)
        
        // Inbox tab
        let inboxVC = InboxViewController()
        inboxVC.tabBarItem = UITabBarItem(title: "Inbox", image: UIImage(systemName: "envelope"), tag: 2)
        
        // Profile tab
        let profileVC = ProfileViewController.forCurrentAccount()
        profileVC.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person"), tag: 3)
        
        // Settings tab (native in original Apollo)
        let settingsVC = SettingsViewController()
        settingsVC.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 4)
        
        self.viewControllers = [
            UINavigationController(rootViewController: homeVC),
            UINavigationController(rootViewController: searchVC),
            UINavigationController(rootViewController: inboxVC),
            UINavigationController(rootViewController: profileVC),
            UINavigationController(rootViewController: settingsVC)
        ]
    }
}
