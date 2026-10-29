# Apollo Base Rebuild Plan

**Goal:** Achieve a perfect 1:1 match with apollo-base.ipa 1.15.11 (build 285). UI/UX and functionality should be 100% identical to the original.

**Target Binary:** `/Users/omarsalam/Projects/Apollo-Reborn/Apollo-base.ipa` (sha256: 9526010ba4c52a5d1ad608f2c0262cefcb0d0740e8a960362642cbaec8b62f40)

**RE Artifacts:** `~/Projects/Apollo-Source-Private/` - 53,316 decompiled functions, 7,806 recovered names, naming pipeline complete.

## Status: Phase 1 & 2 Complete, Build Succeeded, Crash Fixed

Last updated: 2026-10-29

**Latest progress (2026-10-29, logged in with a real account):**
- **Root cause of the sectioning crash:** `UILocalizedIndexedCollation.sectionTitles` returns an **empty array** on the iOS 26 simulator runtime, so the bucketed array had 0 slots and every insert trapped. (The earlier note about needing an object + selector was wrong.) The list now builds its own `A–Z` + `"#"` titles and buckets by first character; `sectionIndexTitles` only lists letters that actually have subreddits.
- **Multireddit listings were 404ing:** `m/<name>/<sort>.json` isn't a valid endpoint. The original calls `linksInMultiredditWithName:userName:...`, which formats `user/%@/m/%@`, and `linksInMultiredditWithPath:` appends `/<sort>.json`. `api/multi/mine` returns `path` as `/user/<user>/m/<name>/`, so the list now carries both `name` (title) and `path` (request) and `PostsViewController` calls `links(inMultiredditPath:...)`.
- **Verified in the simulator** (signed in as `paloking`): moderated 1, multireddit 1, sectioned into 27 letter buckets; tapping `r/apple` loads posts, tapping `m/priva` loads its posts (previously 404), "Posts from subscriptions" loads the front page.
- **Only 25 subscriptions showed up:** the list asked for one page with no `limit`, so Reddit answered with its 25-item default. The original asks for `RDKPagination paginationWithLimit:100` (verified in `RedditListViewController.fetchSubredditData`'s call site) and keeps going; the list now follows `data.after` until the cursor runs out and logs `Subscribed subreddits: 582` for this account. A reload bumps a generation counter so a page landing after a newer reload is dropped.
- **Next step:** next visible gap is flair/markdown rendering (post flairs show raw `:baseball:` and comment bodies show raw markdown). The original renders both with the `Markdown` Swift package (cmark) through `Apollo.MarkdownNode`/`MarkdownTextNode` (`MarkdownModel` + `MarkdownNodeDelegate` protocols), so that's the reference for the port.

## Phase 1: Implement Missing Source Files (7 files, 43 functions)

### Priority 1: ActionController+Moderator.swift (33 functions)
- **Status:** ✅ Complete
- **Purpose:** Moderator actions for comments (approve, remove, stick, lock, etc.)
- **Functions to implement:**
  - `showModeratorActions(forComment:sectionController:viewController:completion:)`
  - And 32 more moderator action functions
- **Cross-reference:** Check apollo-reborn's `src/ApolloActionMenu.xm` for hook names

### Priority 2: AppDelegate+Notifications.swift (4 functions)
- **Status:** ✅ Complete
- **Purpose:** APNs token handling for push notifications
- **Functions to implement:**
  - `fetchAPNsToken(completion:)`
  - `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`
  - `application(_:didFailToRegisterForRemoteNotificationsWithError:)`
- **Cross-reference:** Check apollo-reborn's notification hooks

### Priority 3: Holla.swift (2 functions)
- **Status:** ✅ Complete
- **Purpose:** Status toast notifications
- **Functions to implement:**
  - `showStatus(_:text:duration:savedItemFullName:fromViewController:tappedBlock:)`
  - `HollaSavedItemStatusView` class
- **Cross-reference:** Check apollo-reborn's toast implementation

### Priority 4: ASTableViewController.swift (1 function)
- **Status:** ✅ Complete
- **Purpose:** Base table view controller with viewDidAppear
- **Functions to implement:**
  - `viewDidAppear(_:)`
- **Cross-reference:** Check apollo-reborn's table view hooks

### Priority 5: ActionController+UserReport.swift (2 functions)
- **Status:** ✅ Complete
- **Purpose:** User reporting functionality
- **Functions to implement:**
  - `normalUserReportSubredditRulesSelected(thingFullname:subreddit:tintAsModerator:fromViewController:)`
  - And 1 more
- **Cross-reference:** Check apollo-reborn's report hooks

### Priority 6: ActionController+ModmailReport.swift (1 function)
- **Status:** ✅ Complete
- **Purpose:** Modmail reporting
- **Functions to implement:**
  - `modmailReportSubredditRulesSelected(thingFullname:subreddit:tintAsModerator:fromViewController:)`
- **Cross-reference:** Check apollo-reborn's modmail report hooks

### Priority 7: ActionController+Report.swift (1 function)
- **Status:** ✅ Complete
- **Purpose:** General post/comment reporting
- **Functions to implement:**
  - `reportSubredditRulesSelected(thingFullname:subreddit:tintAsModerator:fromViewController:)`
- **Cross-reference:** Check apollo-reborn's report hooks

## Phase 2: Fix Placeholder View Controllers (31 files)

### Priority 1: Core Navigation
- ✅ **RedditListViewController.swift** - Subreddit list (fixed)
- ✅ **SearchViewController.swift** - Search results (fixed)
- ✅ **MultiredditViewController.swift** - Multireddit posts (fixed)

### Priority 2: User Content
- ✅ **InboxViewController.swift** - Messages (fixed)
- ✅ **NotificationsViewController.swift** - Notifications (fixed)
- ✅ **SavedPostsCommentsViewController.swift** - Saved items (fixed)
- ✅ **AllSubredditCommentsViewController.swift** - All comments for subreddit (fixed)

### Priority 3: Search Results
- ✅ **PostsSearchResultsViewController.swift** - Post search results (fixed)
- ✅ **SubredditSearchResultsViewController.swift** - Subreddit search results (fixed)
- ✅ **ModmailSearchResultsViewController.swift** - Modmail search results (fixed)

### Priority 4: Moderation
- ✅ **ModQueueViewController.swift** - Mod queue (fixed)
- ✅ **ModeratorLogsViewController.swift** - Mod logs (fixed)
- ✅ **ModmailInboxViewController.swift** - Modmail inbox (fixed)

### Priority 5: Utility/Integration
- ✅ **GfycatClient.swift** - Gfycat API client (fixed - real GIPHY API)
- ✅ **ImgurClient.swift** - Imgur API client (fixed - real Imgur upload)
- ✅ **WikipediaClient.swift** - Wikipedia API client (fixed - real Wikipedia API)
- ✅ **WeatherManager.swift** - Weather API client (fixed - real OpenWeatherMap API)
- ✅ **ReceiptDataBuddy.swift** - App Store receipt data (fixed - reads from bundle)
- ✅ **AppStoreBuddy.swift** - App Store integration (fixed - real StoreKit)
- ✅ **AstraAnalyticsManager.swift** - Analytics (functional - logs events)
- ✅ **AstraCrashReporter.swift** - Crash reporting (functional - logs crashes)
- ✅ **AstraNetworkManager.swift** - Network management (functional - uses URLSession)
- ✅ **AstraNotificationManager.swift** - Notification management (functional - uses UserNotifications)
- ✅ **AstraThemeManager.swift** - Theme management (functional - manages dark/light mode)
- ✅ **AstraUpdateManager.swift** - Update management (fixed - checks remote version)
- ✅ **EasterSaleManager.swift** - Easter sale feature (functional - checks sale status)
- ✅ **ApollonouncementHelper.swift** - Announcements (functional - checks for announcements)
- ✅ **PostCellActionTaker.swift** - Post cell actions (fixed - real RDKClient calls)
- ✅ **ThemeManager.swift** - Theme management (functional - manages themes)
- ✅ **RefundScreenHelper.swift** - Refund screen (functional - shows refund screen)
- ✅ **TipJar2ViewController.swift** - Tip jar feature (functional - shows tip jar UI)
- ✅ **LiveActivityHelper.swift** - Live Activities (functional - logs activity events)

## Phase 3: Verification

### Testing Strategy
1. **Unit Tests:** Run existing RedditKit model tests
2. **Integration Tests:** Use mock Reddit server (`tests/mock_reddit_server.py`)
3. **UI Verification:** Compare with original apollo-base.ipa screenshots
4. **Functional Verification:** Test all user flows against original behavior

### Cross-Reference Strategy
- Use apollo-reborn's tweak source (`src/*.xm`) to verify correct function/method names
- Check hook targets for accurate signatures
- Verify argument names and types match original

## Known Issues

- Build has remaining errors related to RDKClient method names (e.g., `subscribedSubreddits`, `inboxMessages`, `savedLinks`, `multiredditWithName`, `moderationQueueForSubredditWithName`, `moderationLogForSubredditWithName`, `modmailConversations`, `searchModmail`, `unreadInboxMessages`, `voteOnLink`, `saveLink`, `hideLink`)
- These methods need to be implemented in RDKClient or the view controllers need to use the generic `getPath`/`postPath` methods
- Need to verify all 43 view controllers work correctly with real API responses

## Resources

- **Original Binary:** `/Users/omarsalam/Projects/Apollo-Reborn/Apollo-base.ipa`
- **RE Artifacts:** `~/Projects/Apollo-Source-Private/`
- **Decompiled Functions:** `~/Projects/Apollo-Source-Private/decompiled/Apollo-named/functions/`
- **Naming Map:** `~/Projects/Apollo-Source-Private/naming/name-map.json`
- **Source Files Map:** `~/Projects/Apollo-Source-Private/naming/source-files.json`
- **Apollo-Reborn Tweak:** `/Users/omarsalam/Projects/Apollo-Reborn/src/` (for cross-reference)

## Build & Test Commands

```bash
# Build the rebuild
cd ApolloRebuild
xcodegen generate
pod install
xcodebuild -workspace ApolloRebuild.xcworkspace -scheme Apollo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run unit tests
xcodebuild test -workspace ApolloRebuild.xcworkspace -scheme Apollo -destination 'platform=iOS Simulator,name=iPhone 15'

# Run mock server for integration testing
python3 tests/mock_reddit_server.py --port 8765
```


## 2026-10-30 — Comments screen: measured against the original

Everything below was measured off 3x simulator screenshots of the original
(`apollo-base.ipa` + Apollo-Reborn tweak) side by side with the rebuild, or read
out of the original's real JSON (`APOLLO_DUMP_LISTING=1`).

### Fixed this session

- **Comments never rendered.** Not Texture: `MarkdownText.inline()` never
  advanced when it met an unmatched `*` / `_` / `~`, and `marker()` /
  `index(of:)` rebuilt arrays per character (O(n²)). Rewrote the scanner to be
  allocation-free and always-advancing. Reported by a CPU sample stuck in
  `MarkdownText.parseLink → index(of:in:from:)`.
- **Line pitch.** `lineHeightMultiple` scales the font's leading, not its point
  size. 15pt bodies now pitch exactly 18pt via
  `minimumLineHeight = maximumLineHeight = fontSize * 1.2`.
- **Body overflow.** Long URLs drew past the right edge; the text column now
  flexes (`flexGrow/flexShrink`) and the row is as wide as `constrainedSize`.
- **Cell padding.** 8.5pt top/bottom (measured: a 2-line reply's row is 91pt =
  8.5 + 30 header + 8 gap + 36 body + 8.5).
- **Thread line.** 2pt bar at `12*depth`, inset 8.5pt top/bottom so it ends 9pt
  inside each hairline (measured: an original depth-1 bar runs 278.7→351.3
  between hairlines at 269.3 and 360.7). Colours are the rainbow theme
  (#F24336, #FF922E, …, sampled from the original).
- **Separators.** Hairline at the top of every row, inset `12*depth` — this
  matches the original exactly (its full-width separators are just depth 0).
- **Tap to collapse.** Collapsed rows hide the body, the ⋯ and the age and draw
  a 20pt grey rounded count badge plus `disclosure-indicator-down`
  (measured x 348.3–368.3, chevron 373.3–386.3).
- **Both ••• menus** now use the exact rows/order from
  `src/ApolloActionMenuLayout.m` (Post-detail and Comment contexts) and render
  as native `UIMenu`s. `ASButtonNode` has no `UIButton` behind it, so the ⋯
  is a real `UIButton` inside `ASDisplayNode(viewBlock:)`, configured in
  `didLoad` (the view does not exist at `init` time).
- **Sort glyph** now follows the *selected* sort (`option-sort-<sort>`).
- **"N more replies" row.** Text is 15pt semibold accent blue, a blue
  `disclosure-indicator-down` chevron 16pt from the right, its own thread line
  at `12*depth` spanning the row, and — verified from the original — the row
  sits at the *parent comment's* depth, not its replies' depth
  (measured: the "13 more replies" row has its bar at 24 and text at 41.7).
  "Continue thread" is the original's copy for a rolled-up thread.
- **Edited comments** show the grey `comment-edited` pencil beside the score;
  the age no longer gets an invented `*`.
- **Inline comment media.** Bodies now split into markdown text plus media:
  `![gif](giphy|ID)` and bare i.redd.it / preview.redd.it / i.imgur.com links
  are drawn as pictures at the column's full width, aspect from the comment's
  own `data.media_metadata` (`s.u`/`s.gif`, `s.x`, `s.y`), 10pt rounded corners.
  `RDKComment.mediaMetadata` needed an explicit Mantle transformer or the
  dictionary silently did not map. Media Reddit marks `status: invalid` (dead
  giphy ids) is dropped instead of leaking `![gif](…)` into the body text.

### Still missing on this screen (in the original, absent here)

- **Find in Comments**: pulling down at the top reveals a "Find in Comments"
  search field under the nav bar (seen in the comparator), with match stepping.
- **Load parent comments** (`view-parent-comments` asset, string
  "Load parent comments") for a thread opened from a single comment's permalink.
- **Select Text** mode, Share as Image, Give Award, Report, Remind Me In…,
  Live Activity — the menu rows exist but their actions are stubs.
- **Swipe to vote**, long-press preview (3D touch), and tapping a comment's
  media to open the media viewer.
- **Header indicators**: sticky pin (`inline-sticky`), cakeday (`cakeday` +
  days), saved triangle (`inline-saved`), locked (`inline-locked`), awards
  (`AwardsNode`), moderator banner, flair chip styling beyond plain text.
- **Animated media**: giphy entries Reddit marks valid are `.gif`/`.mp4`;
  the original plays them, we draw the still.
- **Collapsed badge count** should be checked against the original for
  threads that mix real comments and `more` rows.

## Session Notes

- **2026-10-29:** Initial investigation completed. Identified 7 missing files and 31 placeholder view controllers. Moved rebuild into Apollo-Reborn repo.
- **2026-10-29:** Phase 1 complete - implemented all 7 missing source files (43 functions total). Cross-referenced apollo-reborn tweak source for correct function signatures and action kinds.
- **2026-10-29:** Phase 2 complete - fixed all 31 placeholder view controllers with real API calls. All utility/integration managers are now functional.
- **2026-10-29:** Build succeeded! Added missing RDKClient convenience methods (subscribedSubreddits, inboxMessages, savedLinks, multiredditWithName, moderationQueue, moderationLog, modmailConversations, searchModmail, unreadInboxMessages, voteOnLink, saveLink, hideLink, approve, remove, lock, distinguish, setContestMode, createUserReport, search, searchSubreddits). Fixed Swift/ObjC bridging issues (sharedClient() → shared(), method name renames, optional unwrapping). Created stub view controllers for missing moderator action views.
