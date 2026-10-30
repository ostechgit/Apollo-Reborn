import UIKit
import AsyncDisplayKit
import SafariServices
import AVKit

// Header actions share the same controller operations as the post menu. This
// deliberately does not reuse the feed's gallery action (which opens comments).
extension CommentsViewController: PostCellActionDelegate {
    func postCell(_ cell: LargePostCellNode, didTapVote direction: RDKVoteDirection, on link: RDKLink) {
        self.vote(direction)
    }

    func postCell(_ cell: LargePostCellNode, didTapSaveOn link: RDKLink) {
        self.toggleSave()
    }

    func postCell(_ cell: LargePostCellNode, didTapSubreddit named: String) {
        self.openSubreddit(named)
    }

    func postCell(_ cell: LargePostCellNode, didTapAuthor named: String) {
        self.openAuthor(named)
    }

    func postCell(_ cell: LargePostCellNode, didTapMoreOptionsOn link: RDKLink) {
        // The detail header has its action menu in the navigation bar.
    }

    func postCell(_ cell: LargePostCellNode, didTapMediaOf link: RDKLink) {
        let mediaLink = link.crosspostParent ?? link
        let viewer: UIViewController
        if mediaLink.isGallery, let images = mediaLink.galleryImages {
            let urls = images.compactMap { URL(string: $0.url) }
            guard !urls.isEmpty else { return }
            viewer = MediaPageViewController(mediaURLs: urls)
        } else if mediaLink.isVideo, let url = mediaLink.redditVideoURL.flatMap(URL.init(string:)) {
            let player = AVPlayerViewController()
            player.player = AVPlayer(url: url)
            self.present(player, animated: true) { player.player?.play() }
            return
        } else if mediaLink.isImageLink || mediaLink.domain?.hasSuffix("redd.it") == true {
            let url = mediaLink.isImageLink ? mediaLink.url.flatMap(URL.init(string:))
                : mediaLink.previewImages?.last?.url.flatMap(URL.init(string:))
            guard let url = url else { return }
            viewer = MediaViewerController(mediaURL: url)
        } else if let url = mediaLink.url.flatMap(URL.init(string:)),
                  ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            self.present(SFSafariViewController(url: url), animated: true)
            return
        } else {
            return
        }
        let navigation = UINavigationController(rootViewController: viewer)
        viewer.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done,
            primaryAction: UIAction { [weak navigation] _ in navigation?.dismiss(animated: true) })
        self.present(navigation, animated: true)
    }
}

// CommentsViewController - a post and its comment thread.
// Reconstructed from apollo-base 1.15.11 binary analysis
// (Apollo.CommentsViewController) and measured off 3x screenshots of the
// original.
//
// The original is a ListAdapter-driven table: one header section (the post,
// drawn by CommentsHeaderCellNode) and then one section per comment, each
// followed by its replies in depth-first order. Everything below is a
// flattened version of that shape.
//
// Still to come: finding text in the comments, the 3D-touch preview, live
// sort updates, and the "view parent comments" row when the thread was
// entered from a single comment.

class CommentsViewController: UIViewController, ASTableDataSource, ASTableDelegate {

    // A row in the flattened thread
    enum Row {
        case comment(RDKComment, depth: Int)
        case more(RDKMoreComments, depth: Int)
    }

    let tableNode = ASTableNode(style: .plain)
    private(set) var link: RDKLink
    /// The whole thread, depth-first, as loaded. `rows` is what the table shows:
    /// the same list minus the subtrees hidden behind collapsed comments.
    private var tree: [Row] = []
    private var rows: [Row] = []
    private var commentSort: RDKCommentSortingMethod = .default
    private var expandingMore: Set<String> = []
    /// fullname of every comment the reader has collapsed by tapping it.
    private var collapsedComments: Set<String> = []
    /// Replies hidden behind each collapsed comment, drawn in its badge.
    private var hiddenReplyCounts: [String: Int] = [:]
    /// Kept so the sort button can draw the selected sort's own glyph, which is
    /// what the original does (its glyph is `option-sort-<sort>`).
    private var sortItem: UIBarButtonItem?
    private var moreItem: UIBarButtonItem?
    private var loadGeneration = 0
    private var threadTask: URLSessionDataTask?
    private let refreshControl = UIRefreshControl()
    private var stateView: FeedMessageView?
    private var isLoadingComments = false

    @objc private func refreshControlActivated() {
        self.loadComments(clearExisting: false)
    }

    deinit {
        self.threadTask?.cancel()
    }

    /// Apollo's floating "jump to the next comment" button, bottom right.
    private let jumpButton = UIButton(type: .custom)
    private var jumpTarget = 0
    private let focusedCommentID: String?
    private let context: Int?
    private let continuingThread: Bool

    init(link: RDKLink, commentID: String? = nil, context: Int? = nil, continuingThread: Bool = false) {
        self.link = link
        self.focusedCommentID = commentID
        self.context = context
        self.continuingThread = continuingThread
        super.init(nibName: nil, bundle: nil)
    }

    /// `.default` delegates to Reddit; do not show a misleading Top selection
    /// before an explicit sort is chosen. A suggested sort identifies the server
    /// choice when supplied. Otherwise no checkmark is more honest than a guess.
    private var displayedSort: RDKCommentSortingMethod {
        guard self.commentSort == .default else { return self.commentSort }
        switch self.link.suggestedSort {
        case "top": return .top
        case "confidence", "best": return .best
        case "new": return .new
        case "controversial": return .controversial
        case "old": return .old
        case "qa": return .QA
        case "random": return .random
        default: return .default
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .systemGroupedBackground

        self.tableNode.dataSource = self
        self.tableNode.delegate = self
        // The comments themselves are white cards on the grouped background the
        // original shows above the first comment.
        self.tableNode.backgroundColor = .systemGroupedBackground
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

        // Native owns an ApolloRefreshControl ivar and the
        // refreshControlActivatedWithSender: selector; the rebuild uses UIKit's.
        self.refreshControl.addTarget(self, action: #selector(refreshControlActivated), for: .valueChanged)
        tableView.refreshControl = self.refreshControl

        self.configureFindBar()
        self.configureNavigationBar()
        self.configureJumpButton()
        self.configureViewAllComments()
        self.loadComments()
    }

    // MARK: - Navigation bar

    /// The comments screen's title is a plain "N Comments" pill: unlike the feed
    /// title it opens nothing, so it has no chevron and no menu.
    private func configureNavigationBar() {
        let titleButton = DualLabelTitleButton()
        titleButton.showsChevron = false
        titleButton.showsMenuAsPrimaryAction = false
        titleButton.menu = nil
        titleButton.primaryTitle = self.continuingThread ? "Thread" : PostFormatting.abbreviatedCount(self.link.totalComments) + " Comments"
        titleButton.accessibilityLabel = self.continuingThread ? "Thread" : "Comments"
        self.navigationItem.title = nil
        self.navigationItem.titleView = self.pill(around: titleButton)

        // The original's sort button draws the lines with an up arrow
        // ("option-sort-top"), not the speech-bubble glyph.
        let sort = UIBarButtonItem(image: ApolloAssets.image(named: CommentsViewController.sortGlyph(self.displayedSort)),
                                   menu: self.sortMenu())
        sort.accessibilityLabel = "Sort Comments"
        self.sortItem = sort

        let more = UIBarButtonItem(image: ApolloAssets.image(named: "option-more"),
                                   menu: self.commentsMenu())
        more.accessibilityLabel = "Comment Options"
        self.moreItem = more

        self.navigationItem.rightBarButtonItems = [more, sort]
    }

    /// Wraps a control in the glass capsule iOS 26 draws around nav-bar items.
    private func pill(around control: UIView) -> UIView {
        let size = control.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        control.frame = CGRect(origin: .zero, size: size)
        guard #available(iOS 26.0, *) else { return control }
        let effect = UIGlassEffect(style: .regular)
        effect.isInteractive = false
        let capsule = UIVisualEffectView(effect: effect)
        capsule.frame = CGRect(origin: .zero, size: size)
        capsule.layer.cornerRadius = size.height / 2
        capsule.clipsToBounds = true
        capsule.contentView.addSubview(control)
        capsule.widthAnchor.constraint(equalToConstant: size.width).isActive = true
        capsule.heightAnchor.constraint(equalToConstant: size.height).isActive = true
        return capsule
    }

    // MARK: - Menus

    /// "Sort by…": Top, Best, New, Controversial, Old, Q&A, Random, Live Update,
    /// each with Apollo's own glyph, in the order the original lists them.
    private static func sortGlyph(_ sort: RDKCommentSortingMethod) -> String {
        switch sort {
        case .top: return "option-sort-top"
        case .best: return "option-sort-best"
        case .new: return "option-sort-new"
        case .controversial: return "option-sort-controversial"
        case .old: return "option-sort-old"
        case .QA: return "option-sort-qa"
        case .random: return "option-sort-random"
        case .live: return "option-sort-live"
        default: return "option-sort-top"
        }
    }

    private func sortMenu() -> UIMenu {
        let options: [(String, RDKCommentSortingMethod, String)] = [
            ("Top", .top, "option-sort-top"),
            ("Best", .best, "option-sort-best"),
            ("New", .new, "option-sort-new"),
            ("Controversial", .controversial, "option-sort-controversial"),
            ("Old", .old, "option-sort-old"),
            ("Q&A", .QA, "option-sort-qa"),
            ("Random", .random, "option-sort-random"),
            ("Live Update", .live, "option-sort-live"),
        ]
        let actions = options.map { title, method, icon in
            UIAction(title: title, image: ApolloAssets.image(named: icon),
                     state: self.displayedSort == method ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.commentSort = method
                // The button draws the chosen sort's glyph from now on.
                self.sortItem?.image = ApolloAssets.image(named: CommentsViewController.sortGlyph(method))
                self.collapsedComments.removeAll()
                // Live Update is a Reddit-side comment stream; until that's
                // wired up it loads the thread the same way the others do.
                self.loadComments(clearExisting: true)
            }
        }
        return UIMenu(title: "Sort by\u{2026}", children: actions)
    }

    /// The Post-detail ⋯ menu: the rows the original's comments nav bar shows,
    /// in its order — upvote, downvote, save, reply, author, subreddit,
    /// collapse child comments, select text, share, share as image, crosspost,
    /// find in comments, give award, report, live activity, remind me.
    private func commentsMenu() -> UIMenu {
        let author = self.link.author ?? ""
        let subreddit = self.link.subreddit ?? ""
        var children: [UIMenuElement] = []

        children.append(UIAction(title: "Upvote", image: ApolloAssets.image(named: "option-upvote")) { [weak self] _ in
            self?.vote(.up)
        })
        children.append(UIAction(title: "Downvote", image: ApolloAssets.image(named: "option-downvote")) { [weak self] _ in
            self?.vote(.down)
        })
        children.append(UIAction(title: self.link.saved ? "Unsave" : "Save",
                                 image: ApolloAssets.image(named: self.link.saved ? "option-unsave" : "option-save")) { [weak self] _ in
            self?.toggleSave()
        })
        children.append(UIAction(title: "Reply", image: ApolloAssets.image(named: "option-reply")) { [weak self] _ in
            self?.replyToPost()
        })
        if !author.isEmpty {
            children.append(UIAction(title: author, image: ApolloAssets.image(named: "option-author")) { [weak self] _ in
                self?.openAuthor(author)
            })
        }
        if !subreddit.isEmpty {
            children.append(UIAction(title: subreddit, image: ApolloAssets.image(named: "option-subreddit")) { [weak self] _ in
                self?.openSubreddit(subreddit)
            })
        }
        children.append(UIAction(title: "Collapse Child Comments",
                                 image: ApolloAssets.image(named: "option-collapse-child-comments")) { [weak self] _ in
            self?.collapseAllTopLevelComments()
        })
        children.append(UIAction(title: "Select Text", image: ApolloAssets.image(named: "option-select-mode")) { _ in })
        children.append(UIAction(title: "Share", image: ApolloAssets.image(named: "option-share")) { [weak self] _ in
            self?.share()
        })
        children.append(UIAction(title: "Share as Image\u{2026}",
                                 image: ApolloAssets.image(named: "option-share-as-image")) { _ in })
        children.append(UIAction(title: "Crosspost", image: ApolloAssets.image(named: "option-crosspost")) { _ in })
        children.append(UIAction(title: "Find in Comments", image: ApolloAssets.image(named: "option-search")) { [weak self] _ in
            self?.presentFindInComments()
        })
        children.append(UIAction(title: "Give Award", image: ApolloAssets.image(named: "option-gift-award")) { _ in })
        children.append(UIAction(title: "Report", image: ApolloAssets.image(named: "option-report")) { _ in })
        children.append(UIAction(title: "Live Activity", image: ApolloAssets.image(named: "option-live-activity")) { _ in })
        children.append(UIAction(title: "Remind Me In\u{2026}",
                                 image: ApolloAssets.image(named: "option-remind-me-in")) { _ in })

        return UIMenu(children: children)
    }

    /// "Collapse Child Comments": collapses every top-level thread at once.
    private func collapseAllTopLevelComments() {
        for row in self.tree {
            if case .comment(let comment, let depth) = row, depth == 0, let name = comment.fullName {
                self.collapsedComments.insert(name)
            }
        }
        self.reloadVisibleRows()
    }

    // MARK: - Actions

    private func vote(_ direction: RDKVoteDirection) {
        guard AccountManager.shared.isLogged else { return }
        let previousStatus = self.link.voteStatus
        let previousScore = self.link.score
        func value(_ status: RDKVoteStatus) -> Int {
            switch status {
            case .upvoted: return 1
            case .downvoted: return -1
            default: return 0
            }
        }
        // Tapping the vote you already cast undoes it, as the original's quick
        // bar does.
        let newStatus: RDKVoteStatus = direction == .up
            ? (previousStatus == .upvoted ? .none : .upvoted)
            : (previousStatus == .downvoted ? .none : .downvoted)
        let request: RDKVoteDirection = newStatus == .none ? .none : direction
        self.link.voteStatus = newStatus
        self.link.score = previousScore + value(newStatus) - value(previousStatus)
        self.reloadHeader()

        RDKClient.shared().voteOnThing(withFullName: self.link.fullName ?? "", direction: request) { [weak self] error in
            guard let self = self, let error = error as NSError? else { return }
            self.link.voteStatus = previousStatus
            self.link.score = previousScore
            self.reloadHeader()
            LogBuddy.error("CommentsViewController: vote failed (\(error.code))")
        }
    }

    private func toggleSave() {
        guard AccountManager.shared.isLogged else { return }
        let wasSaved = self.link.saved
        self.link.saved = !wasSaved
        self.reloadHeader()
        let completion: RDKCompletionBlock = { [weak self] error in
            guard let self = self, let error = error as NSError? else { return }
            self.link.saved = wasSaved
            self.reloadHeader()
            LogBuddy.error("CommentsViewController: save failed (\(error.code))")
        }
        if wasSaved {
            RDKClient.shared().unsaveThing(withFullName: self.link.fullName ?? "", completion: completion)
        } else {
            RDKClient.shared().saveThing(withFullName: self.link.fullName ?? "", completion: completion)
        }
    }

    private func replyToPost() {
        guard AccountManager.shared.isLogged, let target = self.link.fullName else { return }
        self.presentReply(to: target)
    }

    private func presentReply(to target: String) {
        let composer = ComposeViewController(replyTo: target) { [weak self] comment in
            guard let self = self else { return }
            self.insertSubmittedComment(comment)
        }
        self.present(UINavigationController(rootViewController: composer), animated: true)
    }

    private func insertSubmittedComment(_ comment: RDKComment) {
        guard !self.tree.contains(where: {
            if case .comment(let existing, _) = $0 { return existing.fullName == comment.fullName }
            return false
        }) else { return }
        // A snapshot requested before the write must not replace the new row.
        self.loadGeneration += 1
        self.threadTask?.cancel()
        self.threadTask = nil
        self.expandingMore.removeAll()
        (self.tree, self.collapsedComments) = Self.insertingSubmittedComment(comment, in: self.tree,
            postFullName: self.link.fullName, collapsed: self.collapsedComments)
        self.link.totalComments += 1
        self.rebuildRows()
        self.configureNavigationBar()
        self.tableNode.reloadData()
        self.updateStateView(error: nil)
    }

    /// Only root replies belong at depth zero. If the parent is absent from
    /// this snapshot, don't misrepresent a nested reply as a top-level comment.
    static func insertingSubmittedComment(_ comment: RDKComment, in tree: [Row],
                                           postFullName: String?, collapsed: Set<String>) -> ([Row], Set<String>) {
        guard let parent = comment.parentID else { return (tree, collapsed) }
        if tree.contains(where: {
            if case .comment(let existing, _) = $0 { return existing.fullName == comment.fullName }
            return false
        }) { return (tree, collapsed) }
        var result = tree
        var expanded = collapsed
        if parent == postFullName {
            result.insert(.comment(comment, depth: 0), at: 0)
        } else if let index = tree.firstIndex(where: {
            if case .comment(let existing, _) = $0 { return existing.fullName == parent }
            return false
        }), case .comment(_, let depth) = tree[index] {
            // Reveal every loaded ancestor, not just the immediate parent.
            var ancestor: String? = parent
            var visited: Set<String> = []
            while let name = ancestor, visited.insert(name).inserted {
                expanded.remove(name)
                ancestor = tree.compactMap { row -> RDKComment? in
                    if case .comment(let existing, _) = row, existing.fullName == name { return existing }
                    return nil
                }.first?.parentID
            }
            result.insert(.comment(comment, depth: depth + 1), at: index + 1)
        }
        return (result, expanded)
    }

    private func share() {
        guard let permalink = self.link.permalink, let url = URL(string: "https://www.reddit.com" + permalink) else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        self.present(activity, animated: true)
    }

    /// Voting or saving redraws the header's info row and quick bar: the cell
    /// is rebuilt from the same link, so its buttons pick up the new state.
    private func reloadHeader() {
        self.moreItem?.menu = self.commentsMenu()
        self.tableNode.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
    }

    private func openLink(_ url: URL) {
        if let route = RedditCommentRoute(url: url), let navigation = self.navigationController {
            route.push(on: navigation)
            return
        }
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        self.present(SFSafariViewController(url: url), animated: true)
    }

    private func openAuthor(_ username: String) {
        self.navigationController?.pushViewController(ProfileViewController(username: username), animated: true)
    }

    private func openSubreddit(_ name: String) {
        self.navigationController?.pushViewController(PostsViewController(postsType: .subreddit(name)), animated: true)
    }

    /// Native viewFullPostNode is a bottom overlay on ordinary focused views,
    /// absent in Continue Thread. Styling/scroll-animation parity is separate.
    private func configureViewAllComments() {
        guard self.focusedCommentID != nil, !self.continuingThread else { return }
        let button = UIButton(type: .system)
        button.setTitle("View All Comments\nThis is a single comment thread from the post.", for: .normal)
        button.titleLabel?.numberOfLines = 2
        button.backgroundColor = .secondarySystemBackground
        button.accessibilityLabel = "View All Comments. This is a single comment thread from the post."
        button.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.navigationController?.pushViewController(CommentsViewController(link: self.link), animated: true)
        }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            button.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            button.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 55)
        ])
        self.tableNode.view.contentInset.bottom = 75
        self.jumpButton.isHidden = true
    }

    // MARK: - Jump button

    /// The floating blue disc bottom-right: one tap scrolls to the next
    /// top-level comment.
    private func configureJumpButton() {
        self.jumpButton.backgroundColor = ThemeManager.shared.accentColor()
        self.jumpButton.layer.cornerRadius = 23
        self.jumpButton.clipsToBounds = true
        self.jumpButton.setImage(ApolloAssets.image(named: "comment-jump-button-arrow")?
            .withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        self.jumpButton.translatesAutoresizingMaskIntoConstraints = false
        self.jumpButton.addTarget(self, action: #selector(jumpTapped), for: .touchUpInside)
        self.view.addSubview(self.jumpButton)
        let bottom = self.jumpButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        NSLayoutConstraint.activate([
            self.jumpButton.widthAnchor.constraint(equalToConstant: 46),
            self.jumpButton.heightAnchor.constraint(equalToConstant: 46),
            self.jumpButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            bottom
        ])
    }

    @objc private func jumpTapped() {
        let topLevel = self.rows.enumerated().compactMap { index, row -> Int? in
            if case .comment(_, let depth) = row, depth == 0 { return index }
            return nil
        }
        guard !topLevel.isEmpty else { return }
        let visible = self.tableNode.view.indexPathsForVisibleRows?.compactMap { $0.section == 1 ? $0.row : nil }.sorted() ?? []
        let currentTop = visible.first ?? 0
        let next = topLevel.first(where: { $0 > currentTop + 1 }) ?? topLevel.first!
        self.jumpTarget = next
        self.tableNode.scrollToRow(at: IndexPath(row: next, section: 1), at: .top, animated: true)
    }

    // MARK: - Loading

    private func loadComments(clearExisting: Bool = false) {
        self.loadGeneration += 1
        let generation = self.loadGeneration
        self.threadTask?.cancel()
        self.expandingMore.removeAll()
        if clearExisting {
            self.tree = []
            self.rebuildRows()
            self.tableNode.reloadData()
        }
        self.sortItem?.menu = self.sortMenu()
        self.isLoadingComments = true
        self.updateStateView(error: nil)
        LogBuddy.debug("Comments: load \(self.link.identifier ?? "nil") sort=\(self.commentSort.rawValue)")
        let completion: RDKLinkAndCommentsCompletionBlock = { [weak self] link, comments, error in
            DispatchQueue.main.async {
                guard let self = self, generation == self.loadGeneration else { return }
                self.threadTask = nil
                self.isLoadingComments = false
                self.refreshControl.endRefreshing()
                if let error = error {
                    // Keep one coherent last-good snapshot on failure. Clearing
                    // only visible rows allowed collapse to resurrect old data.
                    LogBuddy.error("CommentsViewController: thread failed (\((error as NSError).code))")
                    self.rebuildRows()
                    self.updateStateView(error: error)
                    return
                }
                if let link = link { self.link = link }
                self.tree = Self.flatten(comments ?? [], depth: 0)
                self.rebuildRows()
                self.configureNavigationBar()
                self.tableNode.reloadData()
                self.updateStateView(error: nil)
                LogBuddy.debug("Comments: loaded \(self.rows.count) visible rows")
            }
        }
        if let commentID = self.focusedCommentID {
            // Stock 0x100722d24: nil context resolves to zero for Continue
            // Thread, two for ordinary comment permalinks; focused limit is 100.
            self.threadTask = RDKClient.shared().linkAndContext(self.context ?? (self.continuingThread ? 0 : 2),
                forCommentWithIdentifier: commentID, linkIdentifier: self.link.identifier ?? "",
                commentSort: self.commentSort, pagination: RDKPagination(limit: 100), completion: completion)
        } else {
            self.threadTask = RDKClient.shared().linkAndComments(forLinkWithIdentifier: self.link.identifier ?? "",
                commentSort: self.commentSort, pagination: nil, completion: completion)
        }
    }

    /// Loading / empty / error feedback. Native uses spinnerToken and
    /// noCommentsToken adapter sections; their exact cell drawing is unverified,
    /// so this reuses the app's own FeedMessageView convention. Never covers a
    /// thread that still has rows, so a failed refresh keeps readable content.
    private func updateStateView(error: Error?) {
        self.stateView?.removeFromSuperview()
        self.stateView = nil
        guard self.rows.isEmpty else { return }
        // A focused Continue Thread can legitimately be empty while the post
        // header still loads; only advertise empty once a request has finished.
        let model: (String?, String, String?, (() -> Void)?)
        if let error = error {
            model = ("Couldn't Load Comments", error.localizedDescription, "Try Again",
                     { [weak self] in self?.loadComments(clearExisting: false) })
        } else if self.isLoadingComments {
            model = (nil, "Loading…", nil, nil)
        } else {
            model = (nil, "No Comments", nil, nil)
        }
        let view = FeedMessageView(title: model.0, message: model.1, buttonTitle: model.2, action: model.3)
        self.view.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.centerYAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerYAnchor),
            view.leadingAnchor.constraint(equalTo: self.view.readableContentGuide.leadingAnchor, constant: 16),
            view.trailingAnchor.constraint(equalTo: self.view.readableContentGuide.trailingAnchor, constant: -16)
        ])
        self.stateView = view
    }

    /// Recomputes the visible rows from the thread and the collapsed set. A
    /// collapsed comment hides its body and every reply below it, and records
    /// how many replies that was for its badge.
    private func rebuildRows() {
        (self.rows, self.hiddenReplyCounts) = Self.visibleRows(in: self.tree, collapsed: self.collapsedComments)
    }

    /// A more row's indent is presentation, not ancestry: it aligns with its
    /// parent but belongs *inside* that parent's subtree. Use parentID to avoid
    /// leaving the row behind when the parent collapses (including depth zero).
    static func visibleRows(in tree: [Row], collapsed: Set<String>) -> ([Row], [String: Int]) {
        var visible: [Row] = []
        var counts: [String: Int] = [:]
        var index = 0
        while index < tree.count {
            let row = tree[index]
            visible.append(row)
            guard case .comment(let comment, let depth) = row,
                  let name = comment.fullName, collapsed.contains(name) else {
                index += 1
                continue
            }
            var descendants: Set<String> = [name]
            var scan = index + 1
            var hidden = 0
            descendantsLoop: while scan < tree.count {
                switch tree[scan] {
                case .comment(let child, let childDepth):
                    guard childDepth > depth else { break descendantsLoop }
                    if let childName = child.fullName { descendants.insert(childName) }
                    hidden += 1
                case .more(let more, _):
                    guard let parent = more.parentID, descendants.contains(parent) else { break descendantsLoop }
                }
                scan += 1
            }
            counts[name] = hidden
            index = scan
        }
        return (visible, counts)
    }

    /// Redraws after a collapse/expand.
    private func reloadVisibleRows() {
        DispatchQueue.main.async {
            self.rebuildRows()
            self.tableNode.reloadData()
        }
    }

    // MARK: - Collapsing

    /// A tap on a comment collapses or expands its subtree, which is what the
    /// original does (its collapsed row swaps the body for a count badge and a
    /// disclosure chevron).
    private func toggleCollapse(_ comment: RDKComment) {
        guard let name = comment.fullName else { return }
        if self.collapsedComments.contains(name) {
            self.collapsedComments.remove(name)
        } else {
            self.collapsedComments.insert(name)
        }
        self.reloadVisibleRows()
    }

    /// fullname -> the fullname of the comment it replies to, so a comment's
    /// ancestors can be found for "Collapse to Top".
    private var parentMap: [String: String] {
        var map: [String: String] = [:]
        for row in self.tree {
            if case .comment(let comment, _) = row,
               let name = comment.fullName, let parent = comment.parentID, parent.hasPrefix("t1_") {
                map[name] = parent
            }
        }
        return map
    }

    /// "Collapse to Top": collapse every ancestor so this comment's thread
    /// folds up into a single row.
    private func collapseToTop(_ comment: RDKComment) {
        let parents = self.parentMap
        var current = comment.parentID
        while let parent = current, parent.hasPrefix("t1_") {
            self.collapsedComments.insert(parent)
            current = parents[parent]
        }
        self.reloadVisibleRows()
    }

    /// `moreDepth` is the depth of the comment whose replies these are. The
    /// original draws a "N more replies" row at that comment's own depth (bar
    /// and text align with the comment above it), not at its replies' depth.
    static func flatten(_ things: [RDKThing], depth: Int, moreDepth: Int? = nil) -> [Row] {
        var rows: [Row] = []
        for thing in things {
            if let comment = thing as? RDKComment {
                rows.append(.comment(comment, depth: depth))
                rows.append(contentsOf: flatten(comment.replies ?? [], depth: depth + 1, moreDepth: depth))
            } else if let more = thing as? RDKMoreComments {
                rows.append(.more(more, depth: max(0, moreDepth ?? depth)))
            }
        }
        return rows
    }

    // MARK: - Expanding "more replies"

    private func expand(_ more: RDKMoreComments) {
        if more.isContinueThread {
            // Native dispatcher 0x10071ba78 pushes a separate focused thread.
            guard let parent = more.parentID, parent.hasPrefix("t1_"), parent.count > 3 else { return }
            let controller = CommentsViewController(link: self.link,
                commentID: String(parent.dropFirst(3)), continuingThread: true)
            self.navigationController?.pushViewController(controller, animated: true)
            return
        }
        guard let key = more.fullName, !self.expandingMore.contains(key) else { return }
        self.expandingMore.insert(key)
        let generation = self.loadGeneration

        RDKClient.shared().moreComments(more, for: self.link, sort: self.commentSort) { [weak self] collection, error in
            DispatchQueue.main.async {
                guard let self = self, generation == self.loadGeneration else { return }
                self.expandingMore.remove(key)
                // Work against the full tree, not the visible snapshot. The
                // reader may have collapsed the parent or changed sort while
                // the request was in flight. A stale response must not insert
                // rows into a different thread snapshot.
                guard let index = self.tree.firstIndex(where: {
                    if case .more(let other, _) = $0 { return other === more }
                    return false
                }) else { return }
                guard error == nil else {
                    LogBuddy.error("CommentsViewController: morechildren failed")
                    return
                }
                let newRows = Self.rowsFromMoreChildren(collection as? [RDKThing] ?? [], in: self.tree)
                self.tree.replaceSubrange(index...index, with: newRows)
                self.rebuildRows()
                self.tableNode.reloadData()
            }
        }
    }

    /// Unlike a listing, morechildren returns a flat collection. Reassemble
    /// ancestry by parentID rather than assuming API order is depth-first.
    /// Indent more rows at their parent's depth, just as `flatten` does.
    static func rowsFromMoreChildren(_ things: [RDKThing], in tree: [Row]) -> [Row] {
        let names = Set(things.compactMap { $0.fullName })
        let children = Dictionary(grouping: things, by: { thing -> String in
            if let comment = thing as? RDKComment { return comment.parentID ?? "" }
            return (thing as? RDKMoreComments)?.parentID ?? ""
        })
        var depths: [String: Int] = [:]
        for row in tree {
            if case .comment(let comment, let depth) = row, let name = comment.fullName {
                depths[name] = depth
            }
        }
        var result: [Row] = []
        var visited: Set<ObjectIdentifier> = []
        func append(_ thing: RDKThing) {
            guard visited.insert(ObjectIdentifier(thing)).inserted else { return }
            if let comment = thing as? RDKComment {
                let depth = comment.parentID.flatMap { depths[$0] }.map { $0 + 1 } ?? comment.depth
                result.append(.comment(comment, depth: depth))
                if let name = comment.fullName {
                    depths[name] = depth
                    for child in children[name] ?? [] { append(child) }
                }
            } else if let more = thing as? RDKMoreComments {
                let depth = more.parentID.flatMap { depths[$0] } ?? max(0, more.depth - 1)
                result.append(.more(more, depth: depth))
            }
        }
        for thing in things {
            let parent = (thing as? RDKComment)?.parentID ?? (thing as? RDKMoreComments)?.parentID ?? ""
            if !names.contains(parent) { append(thing) }
        }
        // Preserve malformed/orphaned entries without recursing forever on a
        // cycle. Normal responses have already visited everything above.
        for thing in things { append(thing) }
        return result
    }

    private var loadingParents = false

    private var showsParentRow: Bool {
        guard self.focusedCommentID != nil, !self.continuingThread,
              let first = self.tree.first, case .comment(let comment, _) = first else { return false }
        return comment.parentID?.hasPrefix("t1_") == true
    }

    private func loadParentComments() {
        guard self.showsParentRow, !self.loadingParents,
              let first = self.tree.first, case .comment(let anchor, _) = first else { return }
        self.loadingParents = true
        let generation = self.loadGeneration
        RDKClient.shared().context(10, for: anchor) { [weak self] comments, error in
            guard let self = self else { return }
            self.loadingParents = false
            guard generation == self.loadGeneration, error == nil else { return }
            self.tree = Self.mergingParents(comments as? [RDKThing] ?? [], into: self.tree)
            self.rebuildRows()
            self.tableNode.reloadData()
            self.updateStateView(error: nil)
        }
    }

    /// Reconnect the original first-root subtree, never replace it with the
    /// response's stale copy. Native cache walk stops at the matching anchor.
    static func mergingParents(_ incoming: [RDKThing], into tree: [Row]) -> [Row] {
        guard let first = tree.first, case .comment(let anchor, _) = first,
              let anchorName = anchor.fullName else { return tree }
        var parents: [String: RDKComment] = [:]
        func collect(_ things: [RDKThing]) {
            for thing in things {
                guard let comment = thing as? RDKComment else { continue }
                if comment.fullName == anchorName { break }
                if let name = comment.fullName, parents[name] == nil {
                    parents[name] = comment
                    collect(comment.replies ?? [])
                }
            }
        }
        collect(incoming)
        var chain: [RDKComment] = []
        var parent = anchor.parentID
        var visited: Set<String> = [anchorName]
        while let name = parent, visited.insert(name).inserted, let comment = parents[name] {
            chain.append(comment)
            parent = comment.parentID
        }
        guard !chain.isEmpty else { return tree }
        let ancestors = chain.reversed().enumerated().map { Row.comment($0.element, depth: $0.offset) }
        // Only the first root is wrapped. Other roots and their depths survive.
        let boundary = tree.dropFirst().firstIndex { row in
            if case .comment(_, let depth) = row { return depth == 0 }
            if case .more(let more, _) = row { return more.parentID?.hasPrefix("t3_") == true }
            return false
        } ?? tree.endIndex
        let shifted = tree[..<boundary].map { row -> Row in
            switch row {
            case .comment(let comment, let depth): return .comment(comment, depth: depth + chain.count)
            case .more(let more, let depth): return .more(more, depth: depth + chain.count)
            }
        }
        return ancestors + shifted + Array(tree[boundary...])
    }

    // MARK: - ASTableDataSource / ASTableDelegate

    func numberOfSections(in tableNode: ASTableNode) -> Int {
        return 2
    }

    func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
        let count = section == 0 ? (self.showsParentRow ? 2 : 1) : self.rows.count
        return count
    }

    func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        if indexPath.section == 0 {
            if indexPath.row == 1 {
                return {
                    let cell = ASTextCellNode()
                    cell.text = "Load parent comments…"
                    cell.textInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
                    cell.backgroundColor = .systemBackground
                    return cell
                }
            }
            let link = self.link
            return { [weak self] in
                let cell = LargePostCellNode(link: link, isInsideComments: true)
                cell.actionDelegate = self
                cell.onLinkTapped = { [weak self] url in self?.openLink(url) }
                cell.onReplyTapped = { [weak self] in self?.replyToPost() }
                cell.onShareTapped = { [weak self] in self?.share() }
                return cell
            }
        }
        let postAuthor = self.link.author
        switch self.rows[indexPath.row] {
        case .comment(let comment, let depth):
            let collapsed = comment.fullName.map { self.collapsedComments.contains($0) } ?? false
            let hidden = comment.fullName.flatMap { self.hiddenReplyCounts[$0] } ?? 0
            let menu = self.commentMenu(for: comment)
            return {
                let cell = CommentCellNode(comment: comment, depth: depth, postAuthor: postAuthor,
                                           isCollapsed: collapsed, hiddenReplyCount: hidden)
                cell.menu = menu
                cell.onLinkTapped = { [weak self] url in self?.openLink(url) }
                cell.onAuthorTapped = { [weak self] username in self?.openAuthor(username) }
                return cell
            }
        case .more(let more, let depth):
            return { MoreCommentsCellNode(more: more, depth: depth) }
        }
    }

    /// A comment's ⋯ menu: the rows the original's Comment sheet shows, in its
    /// order — upvote, downvote, save, reply, author, select text, share, share
    /// as image, collapse to top, give award, report, remind me.
    private func commentMenu(for comment: RDKComment) -> UIMenu {
        var children: [UIMenuElement] = []

        children.append(UIAction(title: "Upvote", image: ApolloAssets.image(named: "option-upvote")) { [weak self] _ in
            self?.vote(comment, .up)
        })
        children.append(UIAction(title: "Downvote", image: ApolloAssets.image(named: "option-downvote")) { [weak self] _ in
            self?.vote(comment, .down)
        })
        children.append(UIAction(title: comment.saved ? "Unsave" : "Save",
                                 image: ApolloAssets.image(named: comment.saved ? "option-unsave" : "option-save")) { [weak self] _ in
            self?.toggleSave(comment)
        })
        children.append(UIAction(title: "Reply", image: ApolloAssets.image(named: "option-reply")) { [weak self] _ in
            self?.replyToComment(comment)
        })
        if let author = comment.author, !author.isEmpty {
            children.append(UIAction(title: author, image: ApolloAssets.image(named: "option-author")) { [weak self] _ in
                self?.openAuthor(author)
            })
        }
        children.append(UIAction(title: "Select Text", image: ApolloAssets.image(named: "option-select-mode")) { _ in })
        children.append(UIAction(title: "Share", image: ApolloAssets.image(named: "option-share")) { [weak self] _ in
            self?.share(comment)
        })
        children.append(UIAction(title: "Share as Image\u{2026}",
                                 image: ApolloAssets.image(named: "option-share-as-image")) { _ in })
        children.append(UIAction(title: "Collapse to Top",
                                 image: ApolloAssets.image(named: "option-collapse-to-top")) { [weak self] _ in
            self?.collapseToTop(comment)
        })
        children.append(UIAction(title: "Give Award", image: ApolloAssets.image(named: "option-gift-award")) { _ in })
        children.append(UIAction(title: "Report", image: ApolloAssets.image(named: "option-report")) { _ in })
        children.append(UIAction(title: "Remind Me In\u{2026}",
                                 image: ApolloAssets.image(named: "option-remind-me-in")) { _ in })

        return UIMenu(children: children)
    }

    // MARK: - Find in Comments

    /// Native registers a Find in Comments entry (0x1007026b8); its presentation
    /// is unverified, so this adds a compact bar that jumps between matching
    /// comments without changing the loaded tree.
    private let findBar = UIView()
    private let findField = UITextField()
    private let findStatus = UILabel()
    private var findMatches: [Int] = []
    private var findMatchIndex = 0
    private var findBarPriorInset: CGFloat = 0

    private func configureFindBar() {
        self.findField.placeholder = "Find in Comments"
        self.findField.returnKeyType = .search
        self.findField.clearButtonMode = .whileEditing
        self.findField.borderStyle = .roundedRect
        self.findField.accessibilityLabel = "Find in Comments"
        self.findField.addTarget(self, action: #selector(findTextChanged(_:)), for: .editingChanged)

        self.findStatus.font = UIFont.preferredFont(forTextStyle: .footnote)
        self.findStatus.textColor = .secondaryLabel
        self.findStatus.textAlignment = .right
        self.findStatus.setContentHuggingPriority(.required, for: .horizontal)

        let previous = UIButton(type: .system)
        previous.setImage(UIImage(systemName: "chevron.up"), for: .normal)
        previous.accessibilityLabel = "Previous Match"
        previous.addAction(UIAction { [weak self] _ in self?.stepMatch(-1) }, for: .touchUpInside)
        let next = UIButton(type: .system)
        next.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        next.accessibilityLabel = "Next Match"
        next.addAction(UIAction { [weak self] _ in self?.stepMatch(1) }, for: .touchUpInside)
        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.addAction(UIAction { [weak self] _ in self?.endFindInComments() }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [self.findField, self.findStatus, previous, next, done])
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        self.findBar.addSubview(row)
        self.findBar.backgroundColor = .secondarySystemBackground
        self.findBar.isHidden = true
        self.findBar.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.findBar)
        NSLayoutConstraint.activate([
            self.findBar.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.findBar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.findBar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            row.topAnchor.constraint(equalTo: self.findBar.topAnchor, constant: 4),
            row.leadingAnchor.constraint(equalTo: self.findBar.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: self.findBar.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: self.findBar.bottomAnchor, constant: -4)
        ])
    }

    private func presentFindInComments() {
        self.findBar.isHidden = false
        self.view.bringSubviewToFront(self.findBar)
        self.view.layoutIfNeeded()
        // Inset the list instead of drawing the bar over the post header.
        self.findBarPriorInset = self.tableNode.view.contentInset.top
        self.tableNode.view.contentInset.top = self.findBar.bounds.height
        self.tableNode.view.verticalScrollIndicatorInsets.top = self.findBar.bounds.height
        self.findField.becomeFirstResponder()
    }

    @objc private func findTextChanged(_ field: UITextField) {
        let query = field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.findMatches = Self.matchingRows(in: self.rows, query: query)
        self.findMatchIndex = 0
        self.updateFindStatus()
        if let first = self.findMatches.first {
            self.tableNode.scrollToRow(at: IndexPath(row: first, section: 1), at: .middle, animated: true)
        }
    }

    /// Case- and diacritic-insensitive match over comment bodies only; "more"
    /// rows carry no text of their own to search.
    static func matchingRows(in rows: [Row], query: String) -> [Int] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        var matches: [Int] = []
        for (index, row) in rows.enumerated() {
            guard case .comment(let comment, _) = row, let body = comment.body else { continue }
            if body.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                matches.append(index)
            }
        }
        return matches
    }

    private func stepMatch(_ delta: Int) {
        guard !self.findMatches.isEmpty else { return }
        self.findMatchIndex = (self.findMatchIndex + delta + self.findMatches.count) % self.findMatches.count
        self.updateFindStatus()
        self.tableNode.scrollToRow(at: IndexPath(row: self.findMatches[self.findMatchIndex], section: 1),
                                   at: .middle, animated: true)
    }

    private func updateFindStatus() {
        self.findStatus.text = self.findMatches.isEmpty ? "0" : "\(self.findMatchIndex + 1)/\(self.findMatches.count)"
        self.findStatus.accessibilityLabel = self.findMatches.isEmpty
            ? "No matches" : "Match \(self.findMatchIndex + 1) of \(self.findMatches.count)"
    }

    private func endFindInComments() {
        self.findField.resignFirstResponder()
        self.findField.text = ""
        self.findMatches = []
        self.findMatchIndex = 0
        self.findStatus.text = ""
        self.findBar.isHidden = true
        // Restore whatever inset the screen already had.
        self.tableNode.view.contentInset.top = self.findBarPriorInset
        self.tableNode.view.verticalScrollIndicatorInsets.top = 0
    }

    // MARK: - Comment actions

    private func vote(_ comment: RDKComment, _ direction: RDKVoteDirection) {
        guard AccountManager.shared.isLogged else { return }
        let previousStatus = comment.voteStatus
        let previousScore = comment.score
        func value(_ status: RDKVoteStatus) -> Int {
            switch status {
            case .upvoted: return 1
            case .downvoted: return -1
            default: return 0
            }
        }
        let newStatus: RDKVoteStatus = direction == .up
            ? (previousStatus == .upvoted ? .none : .upvoted)
            : (previousStatus == .downvoted ? .none : .downvoted)
        let request: RDKVoteDirection = newStatus == .none ? .none : direction
        comment.voteStatus = newStatus
        comment.score = previousScore + value(newStatus) - value(previousStatus)
        self.tableNode.reloadData()

        RDKClient.shared().voteOnThing(withFullName: comment.fullName ?? "", direction: request) { [weak self] error in
            guard let self = self, let error = error as NSError? else { return }
            comment.voteStatus = previousStatus
            comment.score = previousScore
            self.tableNode.reloadData()
            LogBuddy.error("CommentsViewController: comment vote failed (\(error.code))")
        }
    }

    private func toggleSave(_ comment: RDKComment) {
        guard AccountManager.shared.isLogged else { return }
        let wasSaved = comment.saved
        comment.saved = !wasSaved
        self.tableNode.reloadData()
        let completion: RDKCompletionBlock = { [weak self] error in
            guard let self = self, let error = error as NSError? else { return }
            comment.saved = wasSaved
            self.tableNode.reloadData()
            LogBuddy.error("CommentsViewController: comment save failed (\(error.code))")
        }
        if wasSaved {
            RDKClient.shared().unsaveThing(withFullName: comment.fullName ?? "", completion: completion)
        } else {
            RDKClient.shared().saveThing(withFullName: comment.fullName ?? "", completion: completion)
        }
    }

    private func replyToComment(_ comment: RDKComment) {
        guard AccountManager.shared.isLogged, let target = comment.fullName else { return }
        self.presentReply(to: target)
    }

    private func share(_ comment: RDKComment) {
        let base = "https://www.reddit.com" + (self.link.permalink ?? "")
        guard let url = URL(string: base + (comment.identifier ?? "")) else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        self.present(activity, animated: true)
    }

    func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
        tableNode.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0, indexPath.row == 1 {
            self.loadParentComments()
            return
        }
        guard indexPath.section == 1, indexPath.row < self.rows.count else { return }
        switch self.rows[indexPath.row] {
        case .more(let more, _):
            self.expand(more)
        case .comment(let comment, _):
            self.toggleCollapse(comment)
        }
    }
}
