import UIKit
import AsyncDisplayKit
import AVKit
import SafariServices

// PostsType - what a posts screen lists
// Reconstructed from apollo-base 1.15.11 binary analysis (Apollo.PostsType). The
// original also covers multireddits, moderated subreddits and random subreddits.
enum PostsType {
    case frontPage
    case popular
    case all
    case subreddit(String)
    // A multireddit needs both the name (for the title) and the path Reddit
    // serves its listing from (api/multi/mine's "path", e.g. user/x/m/y)
    case multireddit(name: String, path: String)

    var title: String {
        switch self {
        case .frontPage: return "Home"
        case .popular: return "Popular"
        case .all: return "All"
        case .subreddit(let name): return "r/" + name
        case .multireddit(let name, _): return "m/" + name
        }
    }
}

// PostsViewController - a feed of posts with paging, sorting, voting and saving
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// The original builds on ASTableViewController + ListAdapter and adds the jump
// bar, hide-read-posts, filters and position restoration.

class PostsViewController: UIViewController, ASTableDataSource, ASTableDelegate, PostCellActionDelegate, UISearchBarDelegate {

    let tableNode = ASTableNode(style: .plain)
    let currentPostsType: PostsType
    private(set) var links: [RDKLink] = []

    var currentSort: RDKSubredditCategory = .hot
    var currentTimeSort: RDKTimeSortingMethod = .none

    private var nextPage: RDKPagination?
    private var hasReachedEnd = false
    private var isLoading = false
    // Bumped on every reload so responses for a superseded sort or account are dropped
    private var loadGeneration = 0
    private let pageSize: UInt = 25
    private let refreshControl = UIRefreshControl()
    private var messageView: FeedMessageView?

    init(postsType: PostsType) {
        self.currentPostsType = postsType
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.currentPostsType = .frontPage
        super.init(coder: coder)
    }

    private var isSpecificSubreddit: Bool {
        if case .subreddit = self.currentPostsType { return true }
        return false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Re-apply once the table has a width (and after rotation).
        if self.bannerImage != nil,
           abs((self.tableNode.view.tableHeaderView?.bounds.width ?? 0) - self.tableNode.view.bounds.width) > 1 {
            self.applyBannerHeader()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = self.currentPostsType.title
        self.view.backgroundColor = .systemBackground

        self.tableNode.dataSource = self
        self.tableNode.delegate = self
        self.tableNode.leadingScreensForBatching = 2
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

        self.refreshControl.addTarget(self, action: #selector(refreshControlActivated), for: .valueChanged)
        tableView.refreshControl = self.refreshControl

        // Settings writes these keys; rebuild the visible cells when they change.
        self.appearanceSnapshot = self.currentAppearanceSnapshot()
        NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange),
                                               name: UserDefaults.didChangeNotification, object: nil)

        self.configureNavigationBar()
        self.loadSubredditBanner()

        // A different account (or none) means a different front page and vote state
        NotificationCenter.default.addObserver(self, selector: #selector(accountDidChange), name: AccountManager.accountDidChangeNotification, object: nil)

        self.reloadFromStart()
    }

    // MARK: - Navigation bar
    //
    // 1.15.11's feed nav bar is the stock iOS 26 chrome: a back chevron (the
    // feed is pushed on top of the subreddit list), a title pill, and a grouped
    // right pill holding the trophy button and the feed's ⋯ menu.

    private func configureNavigationBar() {
        // The right pill: the trophy and the feed's ⋯ share one glass capsule.
        let more = UIBarButtonItem(image: ApolloAssets.image(named: "option-more"),
                                   menu: self.feedMenu())
        more.accessibilityLabel = "Feed Options"

        let trophy = UIBarButtonItem(image: ApolloAssets.image(named: "option-trophy")?
            .withTintColor(.label, renderingMode: .alwaysOriginal),
                                     primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            self.navigationController?.pushViewController(ApolloUltraViewController(), animated: true)
        })
        trophy.accessibilityLabel = "Apollo Ultra"

        self.navigationItem.rightBarButtonItems = [more, trophy]

        // The title is Apollo's own DualLabelTitleButton (the "Home ⌄" pill),
        // not the system title: it stays a button with a menu wherever the
        // screen is in its navigation stack.
        self.navigationItem.title = nil
        self.navigationItem.titleView = self.titleBarView()

        // The search field under the nav bar scrolls away with the content, as
        // the original's does. Tapping it opens the Search tab.
        self.navigationItem.searchController = self.feedSearchController
        self.navigationItem.hidesSearchBarWhenScrolling = true
    }

    /// The feed's search field: a plain "Search" field, not a results list -
    /// searching happens on the Search tab.
    private lazy var feedSearchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.searchBar.delegate = self
        controller.searchBar.placeholder = "Search"
        controller.obscuresBackgroundDuringPresentation = false
        return controller
    }()

    // MARK: - Menus

    /// The title bar view: the feed's title button inside the glass capsule the
    /// original draws around it on iOS 26.
    private func titleBarView() -> UIView {
        let button = self.titleButton()
        let size = button.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        button.frame = CGRect(origin: .zero, size: size)
        guard #available(iOS 26.0, *) else { return button }

        let effect = UIGlassEffect(style: .regular)
        effect.isInteractive = true
        let capsule = UIVisualEffectView(effect: effect)
        capsule.frame = CGRect(origin: .zero, size: size)
        capsule.layer.cornerRadius = size.height / 2
        capsule.clipsToBounds = true
        capsule.contentView.addSubview(button)
        capsule.widthAnchor.constraint(equalToConstant: size.width).isActive = true
        capsule.heightAnchor.constraint(equalToConstant: size.height).isActive = true
        return capsule
    }

    /// The feed's title button. It carries the feed name and opens the feed and
    /// sort menu.
    private func titleButton() -> DualLabelTitleButton {
        let button = DualLabelTitleButton()
        button.primaryTitle = self.currentPostsType.title
        button.menu = self.titleMenu()
        button.accessibilityLabel = "Feed"
        return button
    }

    /// The feeds the title can switch to, plus the sort orders (the original
    /// keeps both behind the title).
    private func titleMenu() -> UIMenu {
        var feedActions: [UIMenuElement] = []
        let feeds: [(String, PostsType)] = [
            ("Home", .frontPage), ("Popular", .popular), ("All", .all)
        ]
        for (title, type) in feeds {
            feedActions.append(UIAction(title: title, state: self.matches(type) ? .on : .off) { [weak self] _ in
                self?.switchTo(type)
            })
        }
        for name in self.favoriteSubreddits() {
            feedActions.append(UIAction(title: name, state: self.matches(.subreddit(name)) ? .on : .off) { [weak self] _ in
                self?.switchTo(.subreddit(name))
            })
        }
        return UIMenu(title: "", children: [UIMenu(title: "Feed", options: .displayInline, children: feedActions),
                                            self.sortMenu()])
    }

    private func matches(_ type: PostsType) -> Bool {
        switch (self.currentPostsType, type) {
        case (.frontPage, .frontPage), (.popular, .popular), (.all, .all): return true
        case (.subreddit(let a), .subreddit(let b)): return a.caseInsensitiveCompare(b) == .orderedSame
        default: return false
        }
    }

    private func favoriteSubreddits() -> [String] {
        // Apollo stores its favorites in the app group under "FavoriteSubreddits"
        let group = UserDefaults(suiteName: "group.com.christianselig.apollo")
        let favorites = group?.array(forKey: "FavoriteSubreddits") as? [String]
        return favorites ?? (UserDefaults.standard.array(forKey: "FavoriteSubreddits") as? [String] ?? [])
    }

    private func switchTo(_ type: PostsType) {
        self.navigationController?.pushViewController(PostsViewController(postsType: type), animated: true)
    }

    private func sortMenu() -> UIMenu {
        let sorts: [(String, RDKSubredditCategory)] = [
            ("Hot", .hot), ("Best", .best), ("New", .new), ("Rising", .rising)
        ]
        var items: [UIMenuElement] = sorts.map { title, sort in
            UIAction(title: title, state: self.currentSort == sort ? .on : .off) { [weak self] _ in
                self?.applySort(sort, time: .none)
            }
        }
        let times: [(String, RDKTimeSortingMethod)] = [("Past Hour", .hour), ("Past 24 Hours", .day), ("Past Week", .week), ("Past Month", .month), ("Past Year", .year), ("All Time", .allTime)]
        for (title, sort) in [("Top", RDKSubredditCategory.top), ("Controversial", RDKSubredditCategory.controversial)] {
            let timeActions = times.map { timeTitle, time in
                UIAction(title: timeTitle, state: self.currentSort == sort && self.currentTimeSort == time ? .on : .off) { [weak self] _ in
                    self?.applySort(sort, time: time)
                }
            }
            items.append(UIMenu(title: title, children: timeActions))
        }
        return UIMenu(title: "Sort", children: items)
    }

    /// The feed's ⋯ menu, as measured in the original: Gallery View, Hide Read
    /// Posts, the thumbnail-size toggle and Share. Only the two that the
    /// rebuild can honour are wired up so far.
    private func feedMenu() -> UIMenu {
        let hideRead = UIAction(title: "Hide Read Posts",
                                image: ApolloAssets.image(named: "option-hide-read"),
                                state: self.hidesReadPosts ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.hidesReadPosts.toggle()
            self.applyReadFilter()
            self.configureNavigationBar()
        }
        let share = UIAction(title: "Share", image: ApolloAssets.image(named: "symbol-share")) { [weak self] _ in
            guard let self = self else { return }
            let url: URL?
            switch self.currentPostsType {
            case .frontPage: url = URL(string: "https://www.reddit.com")
            case .popular: url = URL(string: "https://www.reddit.com/r/popular/")
            case .all: url = URL(string: "https://www.reddit.com/r/all/")
            case .subreddit(let name): url = URL(string: "https://www.reddit.com/r/\(name)/")
            case .multireddit(_, let path): url = URL(string: "https://www.reddit.com/\(path)/")
            }
            guard let shareURL = url else { return }
            let controller = UIActivityViewController(activityItems: [shareURL], applicationActivities: nil)
            controller.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItems?.first
            self.present(controller, animated: true)
        }
        // The original switches the feed between the large card and the compact
        // row from this menu (titles recovered in ApolloNativeActionMetadata).
        let compact = UIAction(title: "Compact Posts",
                               image: ApolloAssets.image(named: "option-compact-thumbnails-right"),
                               state: self.usesCompactLayout ? .on : .off) { [weak self] _ in
            guard let self = self, !self.usesCompactLayout else { return }
            self.usesCompactLayout = true
            self.tableNode.reloadData()
            self.configureNavigationBar()
        }
        let large = UIAction(title: "Large Thumbnails",
                             image: ApolloAssets.image(named: "option-large-thumbnails"),
                             state: self.usesCompactLayout ? .off : .on) { [weak self] _ in
            guard let self = self, self.usesCompactLayout else { return }
            self.usesCompactLayout = false
            self.tableNode.reloadData()
            self.configureNavigationBar()
        }
        return UIMenu(title: "", children: [compact, large, hideRead, share])
    }

    /// Compact rows instead of large cards, as the original's feed menu offers.
    /// Stock stores this under `UseCompactThumbnails` (Appearance → "Compact").
    ///
    /// Computed rather than cached so a change made in Settings applies as soon
    /// as the feed is on screen; cell nodes read the value at init, so the table
    /// is rebuilt when it changes.
    private(set) var usesCompactLayout: Bool {
        get { UserDefaults.standard.bool(forKey: "UseCompactThumbnails") }
        set {
            UserDefaults.standard.set(newValue, forKey: "UseCompactThumbnails")
            self.applyAppearanceChange()
        }
    }

    /// Appearance keys the feed renders from. Nodes read these when they are
    /// created, so any change means the visible cells are stale.
    private static let appearanceKeys = [
        "UseCompactThumbnails",
        "CompactModeHideThumbnails",
        "CompactPostsThumbnailSize",
        "LargeThumbnailsShowVotingButtons",
        "ShowPostFlair",
        "ShowUserFlair",
        "ShowAwards",
    ]

    private var appearanceSnapshot: [String] = []

    private func currentAppearanceSnapshot() -> [String] {
        return Self.appearanceKeys.map { key in
            "\(key)=\(String(describing: UserDefaults.standard.object(forKey: key)))"
        }
    }

    private func applyAppearanceChange() {
        self.appearanceSnapshot = self.currentAppearanceSnapshot()
        self.tableNode.reloadData()
        self.configureNavigationBar()
    }

    @objc private func userDefaultsDidChange() {
        guard self.currentAppearanceSnapshot() != self.appearanceSnapshot else { return }
        self.applyAppearanceChange()
    }

    /// Reddit's `visited` flag is what "read" means in the feed.
    private(set) var hidesReadPosts = false

    /// Stock shows the subreddit's header banner in that subreddit's feed
    /// (UltraHeaderBannerTableViewCell), scrolling away with the posts.
    private var bannerImage: UIImage?
    private var bannerRequestURL: String?

    private func loadSubredditBanner() {
        guard case .subreddit(let name) = self.currentPostsType, self.bannerRequestURL == nil else { return }
        self.bannerRequestURL = name
        RDKClient.shared().subredditBanner(forName: name) { [weak self] urlString, _ in
            guard let self = self, let urlString = urlString, let url = URL(string: urlString) else { return }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self, let data = data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    self.bannerImage = image
                    self.applyBannerHeader()
                }
            }.resume()
        }
    }

    /// The header needs the table's real width, which is zero during viewDidLoad.
    private func applyBannerHeader() {
        guard let image = self.bannerImage else { return }
        let width = max(self.tableNode.view.bounds.width, self.view.bounds.width)
        guard width > 0 else { return }
        let host = UIImageView(frame: CGRect(x: 0, y: 0, width: width, height: 110))
        host.image = image
        host.contentMode = .scaleAspectFill
        host.clipsToBounds = true
        self.tableNode.view.tableHeaderView = host
    }

    private func applyReadFilter() {
        self.tableNode.reloadData()
    }

    private var visibleLinks: [RDKLink] {
        return self.hidesReadPosts ? self.links.filter { !$0.visited } : self.links
    }

    @objc private func accountDidChange() {
        self.reloadFromStart()
    }

    @objc private func refreshControlActivated() {
        self.reloadFromStart()
    }

    // MARK: - Loading

    func reloadFromStart() {
        self.loadGeneration += 1
        self.nextPage = nil
        self.hasReachedEnd = false
        self.isLoading = false

        guard RDKClient.shared().hasClientIdentifier else {
            self.links = []
            self.tableNode.reloadData()
            self.refreshControl.endRefreshing()
            self.showMessage(title: "Add Your Reddit API Key",
                             message: "Reddit requires your own API key to load posts. Create an \u{201C}installed app\u{201D} at reddit.com/prefs/apps and enter its client ID.",
                             buttonTitle: "Set Up") { [weak self] in
                guard let self = self else { return }
                LoginViewController.present(from: self)
            }
            return
        }

        if self.links.isEmpty && !self.refreshControl.isRefreshing {
            self.showMessage(title: nil, message: "Loading\u{2026}", buttonTitle: nil, action: nil)
        }
        self.loadNextPage(replacing: true, completion: nil)
    }

    private func loadNextPage(replacing: Bool, completion: (() -> Void)?) {
        guard !self.isLoading else {
            completion?()
            return
        }
        self.isLoading = true
        let generation = self.loadGeneration

        let pagination = RDKPagination(limit: self.pageSize)
        pagination.after = replacing ? nil : self.nextPage?.after
        if self.currentSort == .top || self.currentSort == .controversial {
            pagination.timeMethod = self.currentTimeSort == .none ? .day : self.currentTimeSort
        }

        let handler: RDKListingCompletionBlock = { [weak self] collection, nextPage, error in
            guard let self = self, generation == self.loadGeneration else {
                completion?()
                return
            }
            self.isLoading = false
            self.refreshControl.endRefreshing()
            defer { completion?() }
            
            if let error = error {
                LogBuddy.error("PostsViewController: listing failed (\((error as NSError).domain) \((error as NSError).code))")
                if replacing || self.links.isEmpty {
                    self.links = []
                    self.tableNode.reloadData()
                    self.showMessage(title: "Couldn\u{2019}t Load Posts", message: error.localizedDescription, buttonTitle: "Try Again") { [weak self] in
                        self?.reloadFromStart()
                    }
                }
                return
            }
            
            let newLinks = (collection as? [RDKLink]) ?? []
            self.nextPage = nextPage
            self.hasReachedEnd = nextPage == nil || newLinks.isEmpty
            
            if replacing {
                self.links = newLinks
                self.tableNode.reloadData()
            } else {
                // Pages can overlap when posts shift between requests
                let known = Set(self.links.compactMap { $0.fullName })
                let unique = newLinks.filter { !known.contains($0.fullName ?? "") }
                let start = self.links.count
                self.links.append(contentsOf: unique)
                let indexPaths = (start..<self.links.count).map { IndexPath(row: $0, section: 0) }
                self.tableNode.insertRows(at: indexPaths, with: .none)
            }
            
            if self.links.isEmpty {
                self.showMessage(title: "No Posts", message: "There\u{2019}s nothing here yet.", buttonTitle: nil, action: nil)
            } else {
                self.hideMessage()
            }
        }

        let client = RDKClient.shared()
        switch self.currentPostsType {
        case .frontPage:
            client.frontPageLinks(with: self.currentSort, pagination: pagination, completion: handler)
        case .popular:
            client.links(inSubredditWithName: "popular", category: self.currentSort, pagination: pagination, completion: handler)
        case .all:
            client.linksInAllSubreddits(with: self.currentSort, pagination: pagination, completion: handler)
        case .subreddit(let name):
            client.links(inSubredditWithName: name, category: self.currentSort, pagination: pagination, completion: handler)
        case .multireddit(let name, let path):
            // api/multi/mine's "path" is how Reddit addresses the multi
            // (<path>/<sort>.json); fall back to the named form if it's missing
            if path.isEmpty {
                client.links(inMultireddit: name, userName: AccountManager.shared.username ?? "", category: self.currentSort, pagination: pagination, completion: handler)
            } else {
                client.links(inMultiredditPath: path, category: self.currentSort, pagination: pagination, completion: handler)
            }
        }
    }

    // MARK: - Sorting

    private func applySort(_ sort: RDKSubredditCategory, time: RDKTimeSortingMethod) {
        self.currentSort = sort
        self.currentTimeSort = time
        self.configureNavigationBar()
        self.links = []
        self.tableNode.reloadData()
        self.reloadFromStart()
    }

    // MARK: - ASTableDataSource / ASTableDelegate

    func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
        return self.visibleLinks.count
    }

    func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        let link = self.visibleLinks[indexPath.row]
        let inSpecificSubreddit = self.isSpecificSubreddit
        let compact = self.usesCompactLayout
        return { [weak self] in
            guard let self = self else { return ASCellNode() }
            if compact {
                let node = CompactPostCellNode(link: link, inSpecificSubreddit: inSpecificSubreddit)
                node.actionDelegate = self
                node.onSlideGesture = { [weak self, weak node] point in
                    guard let self = self, let node = node else { return }
                    self.performSlideGesture(point, on: link, cell: node)
                }
                return node
            }
            let node = LargePostCellNode(link: link, inSpecificSubreddit: inSpecificSubreddit)
            node.actionDelegate = self
            node.onSlideGesture = { [weak self, weak node] point in
                guard let self = self, let node = node else { return }
                self.performSlideGesture(point, on: link, cell: node)
            }
            return node
        }
    }

    func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
        tableNode.deselectRow(at: indexPath, animated: true)
        self.navigationController?.pushViewController(CommentsViewController(link: self.visibleLinks[indexPath.row]), animated: true)
    }

    func shouldBatchFetch(for tableNode: ASTableNode) -> Bool {
        return !self.links.isEmpty && !self.hasReachedEnd && !self.isLoading
    }

    func tableNode(_ tableNode: ASTableNode, willBeginBatchFetchWith context: ASBatchContext) {
        // Texture calls this off the main thread
        DispatchQueue.main.async {
            self.loadNextPage(replacing: false) {
                context.completeBatchFetching(true)
            }
        }
    }

    // MARK: - PostCellActionDelegate

    func postCell(_ cell: ASCellNode, didTapVote direction: RDKVoteDirection, on link: RDKLink) {
        guard AccountManager.shared.isLogged else {
            self.promptSignIn(reason: "Sign in to vote on posts.")
            return
        }
        let previousStatus = link.voteStatus
        let previousScore = link.score

        // Show the vote straight away and undo it if Reddit refuses
        func value(_ status: RDKVoteStatus) -> Int {
            switch status {
            case .upvoted: return 1
            case .downvoted: return -1
            default: return 0
            }
        }
        let newStatus: RDKVoteStatus = direction == .up ? .upvoted : (direction == .down ? .downvoted : .none)
        link.voteStatus = newStatus
        link.score = previousScore + value(newStatus) - value(previousStatus)
        (cell as? LargePostCellNode)?.updateActionState()

        RDKClient.shared().voteOnThing(withFullName: link.fullName ?? "", direction: direction) { [weak self, weak cell] error in
            guard let error = error else { return }
            link.voteStatus = previousStatus
            link.score = previousScore
            (cell as? LargePostCellNode)?.updateActionState()
            self?.showError(title: "Couldn\u{2019}t Vote", error: error)
        }
    }

    func postCell(_ cell: ASCellNode, didTapSaveOn link: RDKLink) {
        guard AccountManager.shared.isLogged else {
            self.promptSignIn(reason: "Sign in to save posts.")
            return
        }
        let wasSaved = link.saved
        link.saved = !wasSaved
        (cell as? LargePostCellNode)?.updateActionState()

        let completion: RDKCompletionBlock = { [weak self, weak cell] error in
            guard let error = error else { return }
            link.saved = wasSaved
            (cell as? LargePostCellNode)?.updateActionState()
            self?.showError(title: wasSaved ? "Couldn\u{2019}t Unsave" : "Couldn\u{2019}t Save", error: error)
        }
        if wasSaved {
            RDKClient.shared().unsaveThing(withFullName: link.fullName ?? "", completion: completion)
        } else {
            RDKClient.shared().saveThing(withFullName: link.fullName ?? "", completion: completion)
        }
    }

    /// The ⋯ in a post cell. Apollo opens its own action sheet here (Save,
    /// Hide, Report, Share, ...); this starts with the three the rebuild can
    /// carry out. A stock action sheet stands in until that sheet is rebuilt.
    func postCell(_ cell: ASCellNode, didTapMoreOptionsOn link: RDKLink) {
        let actions: [Action] = [
            Action(title: link.saved ? "Unsave" : "Save", icon: nil, style: .default) { [weak self, weak cell] _ in
                guard let self = self, let cell = cell else { return }
                self.postCell(cell, didTapSaveOn: link)
            },
            Action(title: "Hide", icon: nil, style: .default) { [weak self] _ in
                self?.hide(link)
            },
            Action(title: "Share", icon: nil, style: .default) { [weak self] _ in
                guard let self = self, let url = link.permalinkURL else { return }
                let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                controller.popoverPresentationController?.sourceView = cell.view
                self.present(controller, animated: true)
            }
        ]
        ActionController.shared.showActionSheet(actions: actions, fromViewController: self)
    }

    /// Applies the action configured for `point` in the Posts context
    /// (`PostsSlideGestures`, default upvote / downvote / reply / save).
    private func performSlideGesture(_ point: SlideGesturePoint, on link: RDKLink, cell: ASCellNode) {
        let action = SlideGestureSettings.action(at: point, for: .posts)
        NSLog("[ApolloRebuild] slide gesture posts %@ -> %@", point.rawValueString, action.rawValue)
        switch action {
        case .upvote:
            self.postCell(cell, didTapVote: .up, on: link)
        case .unupvote, .undownvote:
            self.postCell(cell, didTapVote: .none, on: link)
        case .downvote:
            self.postCell(cell, didTapVote: .down, on: link)
        case .save, .unsave:
            self.postCell(cell, didTapSaveOn: link)
        case .hideAbove:
            self.hide(link)
        case .moreOptions:
            self.postCell(cell, didTapMoreOptionsOn: link)
        case .reply:
            // Stock opens the reply composer here; the feed has no composer yet,
            // so this opens the thread, where Reply lives.
            self.navigationController?.pushViewController(CommentsViewController(link: link), animated: true)
        case .collapse, .collapseRoot, .toggleRead, .markRead, .markUnread,
             .post, .selectMode, .parentComment:
            // Meaningless on a feed row (collapse is a comment concept, and the
            // rest are post-detail or composer actions).
            NSLog("[ApolloRebuild] slide action %@ has no effect on a feed row", action.rawValue)
        }
    }

    private func hide(_ link: RDKLink) {
        guard AccountManager.shared.isLogged else {
            self.promptSignIn(reason: "Sign in to hide posts.")
            return
        }
        RDKClient.shared().hideLink(link) { [weak self] error in
            guard let error = error else {
                // A hidden post disappears from the feed, as in the original.
                if let index = self?.links.firstIndex(where: { $0.fullName == link.fullName }) {
                    self?.links.remove(at: index)
                    self?.tableNode.reloadData()
                }
                return
            }
            self?.showError(title: "Couldn\u{2019}t Hide", error: error)
        }
    }

    func postCell(_ cell: ASCellNode, didTapSubreddit named: String) {
        self.navigationController?.pushViewController(PostsViewController(postsType: .subreddit(named)), animated: true)
    }

    func postCell(_ cell: ASCellNode, didTapAuthor named: String) {
        self.navigationController?.pushViewController(ProfileViewController(username: named), animated: true)
    }

    func postCell(_ cell: ASCellNode, didTapMediaOf link: RDKLink) {
        if ImgurAlbumResolver.albumID(from: link.url.flatMap(URL.init(string:))) != nil {
            ImgurAlbumResolver.present(from: self, url: link.url.flatMap(URL.init(string:)))
            return
        }
        if let source = ExternalVideoSource(url: link.url.flatMap(URL.init(string:))) {
            ExternalMediaResolver.present(from: self, source: source)
            return
        }
        if link.isVideo, let videoURL = link.redditVideoURL.flatMap(URL.init(string:)) {
            // v.redd.it's fallback MP4 is video-only; the sound is a separate
            // DASH rendition, so compose them the way the original does.
            RedditVideoComposer.present(from: self, link: link, fallbackURL: videoURL)
        } else if link.isImageLink || (link.hasPreviewImage && !link.isGallery && link.domain?.hasSuffix("redd.it") == true) {
            let imageURL = link.isImageLink ? link.url.flatMap(URL.init(string:)) : link.previewImages?.last?.url.flatMap(URL.init(string:))
            let mediaViewer = MediaViewerController(mediaURL: imageURL)
            let navigationController = UINavigationController(rootViewController: mediaViewer)
            mediaViewer.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak mediaViewer] _ in
                mediaViewer?.dismiss(animated: true)
            })
            self.present(navigationController, animated: true)
        } else if link.isGallery {
            self.navigationController?.pushViewController(CommentsViewController(link: link), animated: true)
        } else if let url = link.url.flatMap(URL.init(string:)), url.scheme?.hasPrefix("http") == true {
            self.present(SFSafariViewController(url: url), animated: true)
        }
    }

    // MARK: - UISearchBarDelegate

    /// The feed's search field is a doorway to the Search tab rather than a live
    /// filter, so it never starts editing here.
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        self.feedSearchController.isActive = false
        if let tabs = self.tabBarController as? ApolloTabBarController {
            tabs.selectedIndex = ApolloTabBarController.Tab.search.rawValue
        }
        return false
    }

    // MARK: - Messages

    private func promptSignIn(reason: String) {
        let alert = UIAlertController(title: "Not Signed In", message: reason, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign In", style: .default) { [weak self] _ in
            guard let self = self else { return }
            LoginViewController.present(from: self)
        })
        self.present(alert, animated: true)
    }

    private func showError(title: String, error: Error) {
        let alert = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }

    private func showMessage(title: String?, message: String, buttonTitle: String?, action: (() -> Void)?) {
        self.hideMessage()
        let messageView = FeedMessageView(title: title, message: message, buttonTitle: buttonTitle, action: action)
        self.view.addSubview(messageView)
        messageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            messageView.centerYAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerYAnchor),
            messageView.leadingAnchor.constraint(equalTo: self.view.readableContentGuide.leadingAnchor, constant: 16),
            messageView.trailingAnchor.constraint(equalTo: self.view.readableContentGuide.trailingAnchor, constant: -16)
        ])
        self.messageView = messageView
    }

    private func hideMessage() {
        self.messageView?.removeFromSuperview()
        self.messageView = nil
    }
}

// FeedMessageView - centered status text for loading, empty and error states
class FeedMessageView: UIView {

    private let action: (() -> Void)?

    init(title: String?, message: String, buttonTitle: String?, action: (() -> Void)?) {
        self.action = action
        super.init(frame: .zero)

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8

        if let title = title {
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = UIFont.preferredFont(forTextStyle: .title3).bold()
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 0
            stackView.addArrangedSubview(titleLabel)
        }

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        stackView.addArrangedSubview(messageLabel)

        if let buttonTitle = buttonTitle {
            var configuration = UIButton.Configuration.filled()
            configuration.title = buttonTitle
            configuration.cornerStyle = .capsule
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 28, bottom: 10, trailing: 28)
            let button = UIButton(configuration: configuration)
            button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
            stackView.setCustomSpacing(20, after: messageLabel)
            stackView.addArrangedSubview(button)
        }

        self.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: self.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func buttonTapped() {
        self.action?()
    }
}
