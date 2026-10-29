import UIKit
import AsyncDisplayKit
import os.log

let apolloLog = OSLog(subsystem: "com.omarsalam.ApolloRebuild", category: "RedditList")

// RedditListViewController - displays a list of subreddits or multireddits
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Original structure (from decompiled code):
// - Section 0: "Posts from subscriptions" with rows: Home, Popular, All, Moderated
// - Section 1: "FAVORITES"
// - Section 2: "MULTIREDDITS" (if any)
// - Section 3: "MODERATED" (subreddits the user moderates)
// - Sections 4+: Alphabetical A-Z sections with section index

class RedditListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var tableView: UITableView?
    private var subreddits: [RDKSubreddit] = []
    private var sectionedSubreddits: [[RDKSubreddit]] = []
    private var favorites: [String] = []
    private var multireddits: [RDKMultireddit] = []
    private var moderatedSubreddits: [RDKSubreddit] = []
    private var isLoading = false
    
    // Section indices
    private let sectionHome = 0
    private let sectionFavorites = 1
    private let sectionMultireddits = 2
    private let sectionModerated = 3
    
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("RedditListViewController viewDidLoad called", log: apolloLog)
        
        self.title = "Home"
        self.view.backgroundColor = UIColor.systemBackground
        
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 44
        tableView.sectionIndexMinimumDisplayRowCount = 15
        tableView.sectionHeaderTopPadding = 0
        
        // Add refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshSubreddits), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        self.view.addSubview(tableView)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: self.view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        
        self.tableView = tableView
        
        // Load subreddits
        loadSubreddits()
    }
    
    @objc private func refreshSubreddits() {
        loadSubreddits()
        self.tableView?.refreshControl?.endRefreshing()
    }
    
    private func loadSubreddits() {
        self.isLoading = true
        os_log("Loading subreddits...", log: apolloLog)
        
        // Load favorites from UserDefaults
        let defaults = UserDefaults.standard
        self.favorites = defaults.stringArray(forKey: "favoriteSubreddits") ?? []
        os_log("Favorites loaded: %d", log: apolloLog, self.favorites.count)
        
        // Fetch subscribed subreddits from Reddit
        let task = RDKClient.shared().subscribedSubreddits(pagination: nil) { [weak self] subreddits, pagination, error in
            os_log("Subreddit request completed", log: apolloLog)
            if let subreddits = subreddits {
                self?.subreddits = subreddits as? [RDKSubreddit] ?? []
                os_log("Loaded %d subreddits", log: apolloLog, self?.subreddits.count ?? 0)
            } else if let error = error {
                os_log("Failed to load subreddits: %s", log: apolloLog, error.localizedDescription)
            }
            
            // Section and sort subreddits
            self?.sectionSubreddits()
            
            self?.isLoading = false
            self?.tableView?.reloadData()
        }
        os_log("Task created: %d", log: apolloLog, task != nil ? 1 : 0)
    }
    
    private func sectionSubreddits() {
        let idxCollation = UILocalizedIndexedCollation()
        
        // Create empty sections for each letter
        self.sectionedSubreddits = []
        for _ in 0..<idxCollation.sectionTitles.count {
            self.sectionedSubreddits.append([])
        }
        
        // Sort subreddits into sections by first character
        for subreddit in self.subreddits {
            let name = subreddit.display_name ?? ""
            if name.isEmpty {
                continue
            }
            let firstChar = name.prefix(1).uppercased()
            // Find the section that starts with this character
            let sectionIndex = idxCollation.sectionTitles.firstIndex(where: { $0 == firstChar }) ?? 0
            if sectionIndex >= 0 && sectionIndex < self.sectionedSubreddits.count {
                self.sectionedSubreddits[sectionIndex].append(subreddit)
            }
        }
        
        // Sort each section
        for i in 0..<self.sectionedSubreddits.count {
            self.sectionedSubreddits[i].sort { a, b in
                (a.display_name ?? "").localizedCaseInsensitiveCompare(b.display_name ?? "") == .orderedAscending
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // Section 0: Home (Posts from subscriptions)
        // Section 1: Favorites
        // Section 2: Multireddits (if any)
        // Section 3: Moderated
        // Sections 4+: Alphabetical A-Z
        
        let total = 4 + self.sectionedSubreddits.count
        return total
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case sectionHome:
            // Home section has fixed rows: Home, Popular, All, Moderated (if applicable)
            var count = 1 // Home (Posts from subscriptions)
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: "showPopularInHome") {
                count += 1 // Popular
            }
            if defaults.bool(forKey: "showAllInHome") {
                count += 1 // All
            }
            if !self.moderatedSubreddits.isEmpty {
                count += 1 // Moderated
            }
            return count
        case sectionFavorites:
            return self.favorites.count
        case sectionMultireddits:
            return self.multireddits.count
        case sectionModerated:
            return self.moderatedSubreddits.count
        default:
            // Alphabetical sections
            let alphaSection = section - 4
            if alphaSection >= 0 && alphaSection < self.sectionedSubreddits.count {
                return self.sectionedSubreddits[alphaSection].count
            }
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case sectionHome:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "HomeCell")
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Posts from subscriptions"
                cell.imageView?.image = UIImage(systemName: "house")
            case 1:
                cell.textLabel?.text = "Popular"
                cell.imageView?.image = UIImage(systemName: "flame")
            case 2:
                cell.textLabel?.text = "All"
                cell.imageView?.image = UIImage(systemName: "globe")
            case 3:
                cell.textLabel?.text = "Moderated"
                cell.imageView?.image = UIImage(systemName: "shield")
            default:
                break
            }
            return cell
        case sectionFavorites:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "FavoriteCell")
            let name = self.favorites[indexPath.row]
            cell.textLabel?.text = "r/" + name
            return cell
        case sectionMultireddits:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "MultiredditCell")
            let multireddit = self.multireddits[indexPath.row]
            cell.textLabel?.text = multireddit.name
            return cell
        case sectionModerated:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "ModeratedCell")
            let subreddit = self.moderatedSubreddits[indexPath.row]
            cell.textLabel?.text = "r/" + (subreddit.display_name ?? "")
            return cell
        default:
            // Alphabetical sections
            let cell = UITableViewCell(style: .default, reuseIdentifier: "SubredditCell")
            let alphaSection = indexPath.section - 4
            if alphaSection >= 0 && alphaSection < self.sectionedSubreddits.count {
                let subreddit = self.sectionedSubreddits[alphaSection][indexPath.row]
                cell.textLabel?.text = "r/" + (subreddit.display_name ?? "")
            }
            return cell
        }
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case sectionHome:
            switch indexPath.row {
            case 0:
                // Home feed (Posts from subscriptions)
                let postsVC = PostsViewController(postsType: .frontPage)
                self.navigationController?.pushViewController(postsVC, animated: true)
            case 1:
                // Popular
                let postsVC = PostsViewController(postsType: .popular)
                self.navigationController?.pushViewController(postsVC, animated: true)
            case 2:
                // All
                let postsVC = PostsViewController(postsType: .all)
                self.navigationController?.pushViewController(postsVC, animated: true)
            case 3:
                // Moderated
                if !self.moderatedSubreddits.isEmpty {
                    let subreddit = self.moderatedSubreddits[0]
                    let postsVC = PostsViewController(postsType: .subreddit(subreddit.name))
                    self.navigationController?.pushViewController(postsVC, animated: true)
                }
            default:
                break
            }
        case sectionFavorites:
            let name = self.favorites[indexPath.row]
            let postsVC = PostsViewController(postsType: .subreddit(name))
            self.navigationController?.pushViewController(postsVC, animated: true)
        case sectionMultireddits:
            let multireddit = self.multireddits[indexPath.row]
            let postsVC = PostsViewController(postsType: .multireddit(multireddit.name))
            self.navigationController?.pushViewController(postsVC, animated: true)
        case sectionModerated:
            let subreddit = self.moderatedSubreddits[indexPath.row]
            let postsVC = PostsViewController(postsType: .subreddit(subreddit.name))
            self.navigationController?.pushViewController(postsVC, animated: true)
        default:
            // Alphabetical sections
            let alphaSection = indexPath.section - 4
            if alphaSection >= 0 && alphaSection < self.sectionedSubreddits.count {
                let subreddit = self.sectionedSubreddits[alphaSection][indexPath.row]
                let postsVC = PostsViewController(postsType: .subreddit(subreddit.name))
                self.navigationController?.pushViewController(postsVC, animated: true)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case sectionHome:
            return nil // No header for home section
        case sectionFavorites:
            return "FAVORITES"
        case sectionMultireddits:
            return "MULTIREDDITS"
        case sectionModerated:
            return "MODERATED"
        default:
            // Alphabetical sections
            let idxCollation = UILocalizedIndexedCollation()
            let alphaSection = section - 4
            if alphaSection >= 0 && alphaSection < idxCollation.sectionTitles.count {
                return idxCollation.sectionTitles[alphaSection]
            }
            return nil
        }
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        let idxCollation = UILocalizedIndexedCollation()
        return idxCollation.sectionTitles
    }
    
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        // Add offset for the non-alphabetical sections
        return index + 4
    }
}

// SubredditCellNode - displays a single subreddit
class SubredditCellNode: ASCellNode {
    
    private let subreddit: RDKSubreddit
    private let label: ASTextNode
    
    init(subreddit: RDKSubreddit) {
        self.subreddit = subreddit
        self.label = ASTextNode()
        super.init()
        
        self.backgroundColor = UIColor.clear
        
        self.label.attributedText = NSAttributedString(
            string: "r/" + (self.subreddit.display_name ?? ""),
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]
        )
        
        self.addSubnode(self.label)
    }
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        return ASInsetLayoutSpec(
            insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16),
            child: self.label
        )
    }
}