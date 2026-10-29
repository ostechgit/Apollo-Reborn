import UIKit
import os.log

let apolloLog = OSLog(subsystem: "com.omarsalam.ApolloRebuild", category: "RedditList")

// RedditListViewController - the Home tab's subreddit list
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Original structure (verified against the shipped app and Apollo Reborn's hooks):
//   section 0  feed shortcuts: "Posts from subscriptions" (Home), Popular, All
//   FAVORITES      Apollo's own favorite list (NSUserDefaults "FavoriteSubreddits")
//   MULTIREDDITS   api/multi/mine
//   MODERATED      subreddits/mine/moderator
//   A-Z            subreddits/mine/subscriber, in UILocalizedIndexedCollation sections
//
// Every section is data, so nothing here does index arithmetic: `sections` is
// rebuilt from the loaded lists and the table just reads it back.
//
// Favorites are a local Apollo concept (not a Reddit subscription), so they come
// from the same defaults key the original uses and refresh when the original's
// notification fires.

final class RedditListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // Apollo's native favorites key and change notification (see Apollo-Reborn's
    // UDKeyApolloFavoriteSubreddits / ApolloFavoriteSubredditsUpdatedNotification)
    private static let favoritesKey = "FavoriteSubreddits"
    private static let favoritesChangedNotification = Notification.Name("com.christianselig.FavoriteSubredditsUpdated")

    // One visible row
    private enum Item {
        case home
        case popular
        case all
        case favorite(String)
        case multireddit(name: String, path: String)
        case moderated(String)
        case subreddit(String)

        var title: String {
            switch self {
            case .home: return "Posts from subscriptions"
            case .popular: return "Popular"
            case .all: return "All"
            case .favorite(let name): return "r/" + name
            case .multireddit(let name, _): return "m/" + name
            case .moderated(let name): return "r/" + name
            case .subreddit(let name): return "r/" + name
            }
        }

        var iconName: String? {
            switch self {
            case .home: return "house"
            case .popular: return "flame"
            case .all: return "globe"
            default: return nil
            }
        }
    }

    // One visible section. `title` is nil for the shortcuts section, which the
    // original draws with no header.
    private struct Section {
        let title: String?
        let items: [Item]
    }

    private var tableView: UITableView?
    private var sections: [Section] = []
    // Titles for the right-edge index; kept parallel to the letter sections in
    // `sections` only, so the index never points at a section that has no rows.
    private var visibleLetterTitles: [String] = []

    private var subscribedSubreddits: [RDKSubreddit] = []
    private var sectionedSubreddits: [[RDKSubreddit]] = []
    private var favorites: [String] = []
    private var multireddits: [RDKMultireddit] = []
    private var moderatedSubreddits: [RDKSubreddit] = []
    private var isLoading = false

    // A-Z plus "#" for anything that isn't a letter. Apollo's list index is the
    // standard one, and building it here avoids UILocalizedIndexedCollation:
    // its -sectionTitles is EMPTY on the iOS 26 runtime, which is what made the
    // original collation-based code crash on an out-of-range bucketed index.
    private static let letterTitles: [String] = {
        let letters = (0..<26).map { String(UnicodeScalar(UInt8(65 + $0))) }
        return letters + ["#"]
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("RedditListViewController viewDidLoad", log: apolloLog)

        self.title = "Home"
        self.view.backgroundColor = UIColor.systemBackground

        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 44
        tableView.sectionIndexMinimumDisplayRowCount = 15
        tableView.sectionHeaderTopPadding = 0

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

        // Favorites live in defaults, so they can change from another screen (or
        // from Apollo's own favorite button) while this list is on screen.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(favoritesChanged),
                                               name: Self.favoritesChangedNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(accountChanged),
                                               name: AccountManager.accountDidChangeNotification,
                                               object: nil)

        reloadAll()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Favorites are local, so a screen that just favorited something must not
        // wait for the notification to reach us
        if loadFavorites() {
            rebuildSections()
            tableView?.reloadData()
        }
    }

    // MARK: - Loading

    @objc private func refreshSubreddits() {
        reloadAll()
    }

    @objc private func favoritesChanged() {
        if loadFavorites() {
            rebuildSections()
            tableView?.reloadData()
        }
    }

    @objc private func accountChanged() {
        reloadAll()
    }

    private func reloadAll() {
        loadFavorites()

        guard AccountManager.shared.isLogged else {
            // Same as the original: the shortcuts stay, the account sections are empty
            os_log("Not signed in; only the feed shortcuts will list", log: apolloLog)
            subscribedSubreddits = []
            moderatedSubreddits = []
            multireddits = []
            finishLoading()
            return
        }

        isLoading = true
        loadSubscribedSubreddits()
        loadModeratedSubreddits()
        loadMultireddits()
    }

    private func loadSubscribedSubreddits() {
        _ = RDKClient.shared().subscribedSubreddits(pagination: nil) { [weak self] subreddits, _, error in
            guard let self = self else { return }
            if let subreddits = subreddits as? [RDKSubreddit] {
                self.subscribedSubreddits = subreddits
                os_log("Subscribed subreddits: %d", log: apolloLog, subreddits.count)
            } else if let error = error {
                os_log("Subscribed subreddits failed: %s", log: apolloLog, error.localizedDescription)
            }
            self.sectionSubreddits()
            self.finishLoading()
        }
    }

    private func loadModeratedSubreddits() {
        _ = RDKClient.shared().moderatedSubreddits(pagination: nil) { [weak self] subreddits, _, error in
            guard let self = self else { return }
            if let subreddits = subreddits as? [RDKSubreddit] {
                self.moderatedSubreddits = subreddits
                os_log("Moderated subreddits: %d", log: apolloLog, subreddits.count)
            } else if let error = error {
                os_log("Moderated subreddits failed: %s", log: apolloLog, error.localizedDescription)
            }
            self.finishLoading()
        }
    }

    private func loadMultireddits() {
        _ = RDKClient.shared().multireddits(pagination: nil) { [weak self] multireddits, _, error in
            guard let self = self else { return }
            if let multireddits = multireddits as? [RDKMultireddit] {
                self.multireddits = multireddits
                os_log("Multireddits: %d", log: apolloLog, multireddits.count)
            } else if let error = error {
                os_log("Multireddits failed: %s", log: apolloLog, error.localizedDescription)
            }
            self.finishLoading()
        }
    }

    // Each of the three requests lands independently; the list reloads as each
    // arrives so a slow one never holds the others back.
    private func finishLoading() {
        isLoading = false
        rebuildSections()
        tableView?.reloadData()
        tableView?.refreshControl?.endRefreshing()
    }

    private func loadFavorites() -> Bool {
        let saved = UserDefaults.standard.stringArray(forKey: Self.favoritesKey) ?? []
        let changed = saved != favorites
        favorites = saved
        return changed
    }

    // MARK: - Sections

    private func rebuildSections() {
        var result: [Section] = []

        // Feed shortcuts are always present, exactly as in the original
        result.append(Section(title: nil, items: [.home, .popular, .all]))

        if !favorites.isEmpty {
            result.append(Section(title: "FAVORITES", items: favorites.map { Item.favorite($0) }))
        }

        if !multireddits.isEmpty {
            let items: [Item] = multireddits.map { multireddit in
                let name = multireddit.name ?? multireddit.displayName ?? ""
                let path = multireddit.path ?? ""
                os_log("Multireddit %s path %s", log: apolloLog, name, path)
                return Item.multireddit(name: name, path: path)
            }
            result.append(Section(title: "MULTIREDDITS", items: items))
        }

        if !moderatedSubreddits.isEmpty {
            let items: [Item] = moderatedSubreddits.map {
                Item.moderated($0.display_name ?? $0.name ?? "")
            }
            result.append(Section(title: "MODERATED", items: items))
        }

        // A-Z, skipping the letters with nothing in them so the index stays honest
        var titles: [String] = []
        for (index, subreddits) in sectionedSubreddits.enumerated() where !subreddits.isEmpty {
            let title = Self.letterTitles[index]
            titles.append(title)
            let items: [Item] = subreddits.map { Item.subreddit($0.display_name ?? $0.name ?? "") }
            result.append(Section(title: title, items: items))
        }

        visibleLetterTitles = titles
        sections = result
    }

    // Bucket subscribed subreddits by the first character of their display name.
    // The original used UILocalizedIndexedCollation, but its -sectionTitles comes
    // back EMPTY on the iOS 26 runtime, so the letter list is built here instead.
    private func sectionSubreddits() {
        let titles = Self.letterTitles
        var buckets = [[RDKSubreddit]](repeating: [], count: titles.count)

        for subreddit in subscribedSubreddits {
            let name = subreddit.display_name ?? subreddit.name ?? ""
            guard !name.isEmpty else { continue }
            buckets[letterSection(for: name)].append(subreddit)
        }

        for index in buckets.indices {
            buckets[index].sort {
                ($0.display_name ?? "").localizedCaseInsensitiveCompare($1.display_name ?? "") == .orderedAscending
            }
        }

        sectionedSubreddits = buckets
        os_log("Sectioned %d subreddits into %d letter sections", log: apolloLog, subscribedSubreddits.count, buckets.count)
    }

    // A-Z map to their own sections; everything that isn't a letter (digits,
    // punctuation, emoji) lands in the trailing "#" section.
    private func letterSection(for name: String) -> Int {
        let titles = Self.letterTitles
        guard let first = name.first else { return titles.count - 1 }

        let uppercased = String(first).uppercased()
        guard let scalar = uppercased.unicodeScalars.first, uppercased.unicodeScalars.count == 1,
              scalar.isASCII, scalar.value >= 65, scalar.value <= 90 else {
            return titles.count - 1
        }
        return Int(scalar.value - 65)
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section].items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "SubredditCell")
            ?? UITableViewCell(style: .default, reuseIdentifier: "SubredditCell")
        cell.textLabel?.text = item.title
        cell.imageView?.image = item.iconName.flatMap { UIImage(systemName: $0) }
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let postsVC: PostsViewController
        switch sections[indexPath.section].items[indexPath.row] {
        case .home:
            postsVC = PostsViewController(postsType: .frontPage)
        case .popular:
            postsVC = PostsViewController(postsType: .popular)
        case .all:
            postsVC = PostsViewController(postsType: .all)
        case .favorite(let name), .moderated(let name), .subreddit(let name):
            postsVC = PostsViewController(postsType: .subreddit(name))
        case .multireddit(let name, let path):
            postsVC = PostsViewController(postsType: .multireddit(name: name, path: path))
        }

        navigationController?.pushViewController(postsVC, animated: true)
    }

    // MARK: - Section index

    // Only letters that actually have subreddits behind them, so tapping "Z" on
    // an account with no Z subreddits can't land on an empty section.
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return visibleLetterTitles.isEmpty ? nil : visibleLetterTitles
    }

    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        // Resolve by title instead of arithmetic, since the fixed sections above
        // are only present when they have content.
        return sections.firstIndex { $0.title == title } ?? 0
    }
}

// SubredditCellNode lives in SubredditCellNode.swift, shared with the search results
