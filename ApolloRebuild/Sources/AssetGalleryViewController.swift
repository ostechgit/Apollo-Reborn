import UIKit

// AssetGalleryViewController - development aid, not part of the original app.
//
// The rebuild can only use artwork that exists in Apollo's own Assets.car, and
// the catalog is a flat list of ~900 names with no descriptions. Rather than
// guess which name is which glyph, this screen renders a candidate list so the
// right name can be picked by looking at it.
//
// It only appears when the app is launched with APOLLO_ASSET_GALLERY set:
//
//     SIMCTL_CHILD_APOLLO_ASSET_GALLERY=1 scripts/run-in-sim.sh
//
// Nothing here ships: with the variable unset the normal app starts.

final class AssetGalleryViewController: UITableViewController {

    private let names: [String]

    private init(names: [String]) {
        self.names = names
        super.init(style: .plain)
        self.title = "Assets.car"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func galleryIfRequested() -> UIViewController? {
        guard ProcessInfo.processInfo.environment["APOLLO_ASSET_GALLERY"] != nil else {
            return nil
        }
        let names = [
            // Post cell chrome
            "option-more", "inline-more-options", "media-viewer-more", "slide-more-hollow",
            "inline-upvote", "inline-downvote", "option-upvote", "option-downvote",
            "posts-points", "posts-points-small", "posts-comments", "posts-comments-small",
            "posts-clock", "posts-clock-small", "posts-edited", "posts-views", "posts-liked",
            "inline-saved", "saved-triangle-small", "saved-triangle", "crosspost-small",
            "cakeday", "option-trophy", "small-link",
            // Obscuring / media overlays
            "obscured-nsfw", "obscured-spoiler", "obscured-video",
            "compact-playhead-icon", "video-playhead-large", "video-gif-progress-bar",
            // Feed menu
            "table-grid", "table-list", "option-hide-read", "hide-read-posts-button-eye",
            "option-share", "option-save", "option-hide", "symbol-share", "symbol-hide",
            // Link buttons
            "link-button-safari", "link-button-image", "link-button-video", "link-button-album",
            "link-button-wikipedia", "link-button-xkcd", "link-button-twitter",
            // Subreddit stand-ins
            "subreddit-a", "subreddit-j", "subreddit-s", "subreddit-0", "snoomoji-loading-square",
            // Tab bar
            "tab-bar-posts", "tab-bar-inbox", "tab-bar-profile", "tab-bar-search", "tab-bar-settings",
            // Obscured/NSFW chips
            "option-nsfw", "option-spoiler", "symbol-flair"
        ]
        return AssetGalleryViewController(names: names)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableView.rowHeight = 56
        self.navigationController?.navigationBar.prefersLargeTitles = false
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.names.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let name = self.names[indexPath.row]
        var configuration = cell.defaultContentConfiguration()
        configuration.text = name
        configuration.textProperties.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        // Template images need an explicit tint to be visible on the white row
        configuration.image = ApolloAssets.image(named: name)?
            .withTintColor(.black, renderingMode: .alwaysOriginal)
        configuration.imageProperties.maximumSize = CGSize(width: 32, height: 32)
        cell.contentConfiguration = configuration
        return cell
    }
}
