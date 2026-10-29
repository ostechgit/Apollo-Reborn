import UIKit
import AsyncDisplayKit

// ProfileViewController - displays a user's profile
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ProfileViewController: UIViewController, ASTableDataSource, ASTableDelegate {
    
    private let tableNode = ASTableNode(style: .plain)
    private var posts: [RDKLink] = []
    private var username: String
    private var isLoading = false

    // The Profile tab shows whoever is signed in, and a sign-in prompt when nobody is
    private var followsCurrentAccount = false
    private var signInPromptView: SignInPromptView?

    init(username: String) {
        self.username = username
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.username = ""
        super.init(coder: coder)
    }

    static func forCurrentAccount() -> ProfileViewController {
        let profileVC = ProfileViewController(username: AccountManager.shared.username ?? "")
        profileVC.followsCurrentAccount = true
        return profileVC
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.systemBackground
        
        self.tableNode.dataSource = self
        self.tableNode.delegate = self
        self.tableNode.backgroundColor = .systemBackground
        self.view.addSubnode(self.tableNode)
        
        let tableView = self.tableNode.view
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: self.view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])

        if self.followsCurrentAccount {
            NotificationCenter.default.addObserver(self, selector: #selector(accountDidChange), name: AccountManager.accountDidChangeNotification, object: nil)
            self.updateForCurrentAccount()
        } else {
            self.navigationItem.title = "u/" + self.username
            loadProfile()
        }
    }

    @objc private func accountDidChange() {
        self.updateForCurrentAccount()
    }

    private func updateForCurrentAccount() {
        guard let username = AccountManager.shared.username else {
            self.username = ""
            self.posts = []
            self.tableNode.reloadData()
            self.tableNode.isHidden = true
            // navigationItem, not title: setting title would also rename the tab
            self.navigationItem.title = "Profile"
            self.navigationItem.rightBarButtonItem = nil

            if self.signInPromptView == nil {
                let promptView = SignInPromptView(message: "Sign in to see your profile, posts and comments.") { [weak self] in
                    guard let self = self else { return }
                    LoginViewController.present(from: self)
                }
                self.view.addSubview(promptView)
                promptView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    promptView.topAnchor.constraint(equalTo: self.view.topAnchor),
                    promptView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                    promptView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                    promptView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
                ])
                self.signInPromptView = promptView
            }
            return
        }

        self.signInPromptView?.removeFromSuperview()
        self.signInPromptView = nil
        self.tableNode.isHidden = false
        self.username = username
        self.navigationItem.title = "u/" + username
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Sign Out", style: .plain, target: self, action: #selector(signOutTapped))
        loadProfile()
    }

    @objc private func signOutTapped() {
        let alert = UIAlertController(title: "Sign out of u/\(self.username)?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { _ in
            AccountManager.shared.logout()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        self.present(alert, animated: true)
    }

    private func loadProfile() {
        self.isLoading = true
        
        // The user's submitted posts, newest first
        let pagination = RDKPagination(limit: 25)
        pagination.userContentSortingMethod = .new
        RDKClient.shared().submittedLinksByUser(withUsername: self.username, pagination: pagination) { [weak self] collection, _, error in
            guard let self = self else { return }
            self.isLoading = false
            if let error = error {
                LogBuddy.error("ProfileViewController: submitted posts failed (\((error as NSError).code))")
            }
            self.posts = (collection as? [RDKLink]) ?? []
            self.tableNode.reloadData()
        }
    }
    
    // MARK: - ASTableDataSource / ASTableDelegate
    
    func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
        return self.posts.count
    }
    
    func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        let post = self.posts[indexPath.row]
        return { PostCellNode(post: post) }
    }
    
    func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
        tableNode.deselectRow(at: indexPath, animated: true)
        self.navigationController?.pushViewController(CommentsViewController(link: self.posts[indexPath.row]), animated: true)
    }
}
