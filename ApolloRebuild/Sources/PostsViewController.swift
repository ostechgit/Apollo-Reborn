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
    case multireddit(String)
    
    var title: String {
        switch self {
        case .frontPage: return "Home"
        case .popular: return "Popular"
        case .all: return "All"
        case .subreddit(let name): return "r/" + name
        case .multireddit(let name): return "m/" + name
        }
    }
}

// PostsViewController - a feed of posts with paging, sorting, voting and saving
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// The original builds on ASTableViewController + ListAdapter and adds the jump
// bar, hide-read-posts, filters and position restoration.

class PostsViewController: UIViewController, ASTableDataSource, ASTableDelegate, PostCellActionDelegate {
    
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
        
        self.updateSortButton()
        
        // A different account (or none) means a different front page and vote state
        NotificationCenter.default.addObserver(self, selector: #selector(accountDidChange), name: AccountManager.accountDidChangeNotification, object: nil)
        
        self.reloadFromStart()
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
        case .multireddit(let name):
            // Multireddits use the same endpoint as subreddits
            client.links(inSubredditWithName: name, category: self.currentSort, pagination: pagination, completion: handler)
        }
    }
    
    // MARK: - Sorting
    
    private func updateSortButton() {
        let sorts: [(String, String, RDKSubredditCategory)] = [
            ("Hot", "flame", .hot), ("Best", "rosette", .best), ("New", "sparkles", .new), ("Rising", "chart.line.uptrend.xyaxis", .rising)
        ]
        var items: [UIMenuElement] = sorts.map { title, image, sort in
            UIAction(title: title, image: UIImage(systemName: image), state: self.currentSort == sort ? .on : .off) { [weak self] _ in
                self?.applySort(sort, time: .none)
            }
        }
        let times: [(String, RDKTimeSortingMethod)] = [("Past Hour", .hour), ("Past 24 Hours", .day), ("Past Week", .week), ("Past Month", .month), ("Past Year", .year), ("All Time", .allTime)]
        for (title, image, sort) in [("Top", "chart.bar", RDKSubredditCategory.top), ("Controversial", "bolt", RDKSubredditCategory.controversial)] {
            let timeActions = times.map { timeTitle, time in
                UIAction(title: timeTitle, state: self.currentSort == sort && self.currentTimeSort == time ? .on : .off) { [weak self] _ in
                    self?.applySort(sort, time: time)
                }
            }
            items.append(UIMenu(title: title, image: UIImage(systemName: image), children: timeActions))
        }
        let button = UIBarButtonItem(image: UIImage(systemName: "arrow.up.arrow.down"), menu: UIMenu(title: "Sort Posts", children: items))
        button.accessibilityLabel = "Sort"
        self.navigationItem.rightBarButtonItem = button
    }
    
    private func applySort(_ sort: RDKSubredditCategory, time: RDKTimeSortingMethod) {
        self.currentSort = sort
        self.currentTimeSort = time
        self.updateSortButton()
        self.links = []
        self.tableNode.reloadData()
        self.reloadFromStart()
    }
    
    // MARK: - ASTableDataSource / ASTableDelegate
    
    func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
        return self.links.count
    }
    
    func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        let link = self.links[indexPath.row]
        let inSpecificSubreddit = self.isSpecificSubreddit
        return { [weak self] in
            let node = LargePostCellNode(link: link, inSpecificSubreddit: inSpecificSubreddit)
            node.actionDelegate = self
            return node
        }
    }
    
    func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
        tableNode.deselectRow(at: indexPath, animated: true)
        self.navigationController?.pushViewController(CommentsViewController(link: self.links[indexPath.row]), animated: true)
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
    
    func postCell(_ cell: LargePostCellNode, didTapVote direction: RDKVoteDirection, on link: RDKLink) {
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
        cell.updateActionState()
        
        RDKClient.shared().voteOnThing(withFullName: link.fullName ?? "", direction: direction) { [weak self, weak cell] error in
            guard let error = error else { return }
            link.voteStatus = previousStatus
            link.score = previousScore
            cell?.updateActionState()
            self?.showError(title: "Couldn\u{2019}t Vote", error: error)
        }
    }
    
    func postCell(_ cell: LargePostCellNode, didTapSaveOn link: RDKLink) {
        guard AccountManager.shared.isLogged else {
            self.promptSignIn(reason: "Sign in to save posts.")
            return
        }
        let wasSaved = link.saved
        link.saved = !wasSaved
        cell.updateActionState()
        
        let completion: RDKCompletionBlock = { [weak self, weak cell] error in
            guard let error = error else { return }
            link.saved = wasSaved
            cell?.updateActionState()
            self?.showError(title: wasSaved ? "Couldn\u{2019}t Unsave" : "Couldn\u{2019}t Save", error: error)
        }
        if wasSaved {
            RDKClient.shared().unsaveThing(withFullName: link.fullName ?? "", completion: completion)
        } else {
            RDKClient.shared().saveThing(withFullName: link.fullName ?? "", completion: completion)
        }
    }
    
    func postCell(_ cell: LargePostCellNode, didTapMediaOf link: RDKLink) {
        if link.isVideo, let videoURL = link.redditVideoURL.flatMap(URL.init(string:)) {
            // v.redd.it's fallback MP4 has no audio track; the original remuxes DASH audio in
            let player = AVPlayerViewController()
            player.player = AVPlayer(url: videoURL)
            self.present(player, animated: true) {
                player.player?.play()
            }
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
