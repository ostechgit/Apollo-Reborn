import UIKit
import Eureka

// SettingsAppearanceViewController - Apollo's Appearance settings.
//
// Rebuilt from the base binary. Every row below was recovered by reading its key
// literal out of the same builder function as its title literal
// (`SettingsAppearanceViewController`'s row builders in the
// 0x1001f0000-0x1001f4b00 block). See RE/settings-reference.md.
//
// Two stock rows are intentionally absent because their option labels are not
// recovered, only their keys:
//   Post Size Per Subreddit   RedditPostSizeMapping   (sub-screen)
//   Show GIF Progress         ShowGIFProgressLocation (raw values exist:
//                             everywhere / thumbnail / mediaViewer)
// Adding them with guessed option titles would put invented UI in front of the
// user, so they are left out until the labels are decoded.

class SettingsAppearanceViewController: FormViewController {

    /// Stock seeds these from Defaults.plist, but a fresh install of this rebuild
    /// may have no value at all, so each row falls back to its stock default.
    private static func bool(_ key: String, default fallback: Bool) -> Bool {
        return UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
    }

    private static func switchRow(_ tag: String, _ title: String, key: String,
                                  default fallback: Bool) -> SwitchRow {
        return SwitchRow(tag) { row in
            row.title = title
            row.value = Self.bool(key, default: fallback)
            row.onChange { row in
                UserDefaults.standard.set(row.value ?? false, forKey: key)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Appearance"
        self.buildForm()
    }

    private func buildForm() {
        self.form = Form()

        // MARK: Feed
        let feed = Section()
        feed.append(Self.switchRow("compact", "Compact", key: "UseCompactThumbnails", default: false))
        feed.append(Self.switchRow("subredditIconsPosts", "Show Subreddit Icons",
                                   key: "ShowSubredditIconsForPosts", default: false))
        feed.append(Self.switchRow("subredditIconsList", "Show Subreddit Icons in List",
                                   key: "ShowSubredditIconsInSubredditList", default: false))
        feed.append(Self.switchRow("subredditAtTop", "Show Subreddit at Top",
                                   key: "ShowSubredditAtTop", default: false))
        feed.append(Self.switchRow("usernames", "Always Show Usernames",
                                   key: "AlwaysShowUsernames", default: false))
        feed.append(Self.switchRow("pageEndings", "Show Page Endings",
                                   key: "ShowPageEndings", default: false))
        self.form.append(feed)

        // MARK: Large cards
        let large = Section("Large Cards")
        large.append(Self.switchRow("largeVoting", "Show Voting Buttons",
                                    key: "LargeThumbnailsShowVotingButtons", default: true))
        self.form.append(large)

        // MARK: Compact rows
        let compact = Section("Compact Rows")

        // Thumbnail Size folds the stock "Hidden" option into the size picker:
        // Hidden is the `CompactModeHideThumbnails` bool, the rest set
        // `CompactPostsThumbnailSize`.
        compact.append(
            ActionSheetRow<String>("thumbnailSize") { row in
                row.title = "Thumbnail Size"
                row.options = ["Hidden", "Small (Default)", "Medium", "Large"]
                if UserDefaults.standard.bool(forKey: "CompactModeHideThumbnails") {
                    row.value = "Hidden"
                } else {
                    switch UserDefaults.standard.string(forKey: "CompactPostsThumbnailSize") {
                    case "medium": row.value = "Medium"
                    case "large": row.value = "Large"
                    default: row.value = "Small (Default)"
                    }
                }
                row.onChange { row in
                    switch row.value {
                    case "Hidden":
                        UserDefaults.standard.set(true, forKey: "CompactModeHideThumbnails")
                    case "Medium", "Large":
                        UserDefaults.standard.set(false, forKey: "CompactModeHideThumbnails")
                        UserDefaults.standard.set(row.value == "Medium" ? "medium" : "large",
                                                  forKey: "CompactPostsThumbnailSize")
                    default:
                        UserDefaults.standard.set(false, forKey: "CompactModeHideThumbnails")
                        UserDefaults.standard.set("small", forKey: "CompactPostsThumbnailSize")
                    }
                }
            }
        )

        compact.append(
            ActionSheetRow<String>("thumbnailPosition") { row in
                row.title = "Thumbnail Position"
                row.options = ["Left", "Right"]
                row.value = Self.bool("CompactModeLeftThumbnails", default: true) ? "Left" : "Right"
                row.onChange { row in
                    UserDefaults.standard.set(row.value == "Left",
                                              forKey: "CompactModeLeftThumbnails")
                }
            }
        )

        compact.append(Self.switchRow("selfThumbnails", "Show Self Post Thumbnails",
                                      key: "CompactModeShowSelfPostThumbnails", default: true))

        // The row reads "Show Voting Buttons" but the stored key records hiding,
        // so the toggle is inverted on read and write.
        compact.append(
            SwitchRow("compactVoting") { row in
                row.title = "Show Voting Buttons"
                row.value = !Self.bool("CompactModeHideVotingButtons", default: false)
                row.onChange { row in
                    UserDefaults.standard.set(!(row.value ?? true),
                                              forKey: "CompactModeHideVotingButtons")
                }
            }
        )

        compact.append(
            ActionSheetRow<String>("votingPosition") { row in
                row.title = "Voting Buttons Position"
                row.options = ["Left", "Right"]
                row.value = Self.bool("CompactModeRightVotingButtons", default: true) ? "Right" : "Left"
                row.onChange { row in
                    UserDefaults.standard.set(row.value == "Right",
                                              forKey: "CompactModeRightVotingButtons")
                }
            }
        )
        self.form.append(compact)

        // MARK: Media and metadata
        let media = Section()
        media.append(Self.switchRow("mediaViewer", "Show Media Viewer Controls",
                                    key: "ShowMediaViewerControlsWhenOpened", default: true))
        media.append(Self.switchRow("postFlair", "Show Post Flair",
                                    key: "ShowPostFlair", default: true))
        media.append(Self.switchRow("userFlair", "Show User Flair",
                                    key: "ShowUserFlair", default: true))
        media.append(Self.switchRow("awards", "Show Awards",
                                    key: "ShowAwards", default: true))
        self.form.append(media)
    }
}
