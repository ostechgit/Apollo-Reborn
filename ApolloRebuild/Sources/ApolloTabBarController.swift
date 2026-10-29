import UIKit

// ApolloTabBarController - main tab bar controller for the app
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ApolloTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create tabs
        let homeVC = PostsViewController(postsType: .frontPage)
        homeVC.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)
        
        let popularVC = PostsViewController(postsType: .popular)
        popularVC.tabBarItem = UITabBarItem(title: "Popular", image: UIImage(systemName: "flame"), tag: 1)
        
        let searchVC = SearchViewController()
        searchVC.tabBarItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), tag: 2)
        
        let inboxVC = InboxViewController()
        inboxVC.tabBarItem = UITabBarItem(title: "Inbox", image: UIImage(systemName: "envelope"), tag: 3)
        
        let profileVC = ProfileViewController.forCurrentAccount()
        profileVC.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person"), tag: 4)
        
        self.viewControllers = [
            UINavigationController(rootViewController: homeVC),
            UINavigationController(rootViewController: popularVC),
            UINavigationController(rootViewController: searchVC),
            UINavigationController(rootViewController: inboxVC),
            UINavigationController(rootViewController: profileVC)
        ]
    }
}
