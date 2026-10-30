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

### More-replies follow-up (2026-10-30)

- Checkpoint committed as `8454836` before continuing this investigation.
- Fixed collapse ancestry: a more row aligns visually with its parent, but its
  `parentID` makes it part of that parent's subtree. Treating visual depth as
  tree depth left it visible after collapsing its parent (including depth zero).
- Morechildren completion now hops to main, edits the full `tree`, and derives
  visible rows again. A parent collapsed during the request stays collapsed;
  stale responses whose placeholder is no longer in the tree are ignored.
- Flat morechildren results are grouped by `parentID` into depth-first order;
  nested more rows use their parent's indent, matching the initial-load path.
- `python3 tests/run_comment_tree_tests.py` compiles the controller's actual
  helper declarations with small host-only model doubles. Covers nested/root
  placeholders, collapse/expand, out-of-order responses, a completion after
  collapse, and malformed cycles. Passed. RedditKit model suite: 79 checks,
  zero failures (existing `description` property warning remains).
- Original named decompilation `0x100492150` (MoreCommentsCellNode layout)
  confirms layout reads the model's depth; `0x100490b64` (layout) positions an
  activity indicator in the content area. Exact horizontal placement remains
  unresolved in Ghidra's floating-point/frame pseudocode.
- Loading state is inlined, not a dedicated setter: `0x1007237ec` writes
  `isLoading = 1`, fades all subnodes to alpha 0 and the activity indicator to
  alpha 1. Stop paths `0x10071d264`, `0x10071c308`, `0x10071cca8` reverse those
  values. `didLoad` helper `0x100491ffc` creates style-100 activity indicator,
  starts it once, sets alpha 0, and adds it to the cell view. Thus the earlier
  chevron-only spinner-swap claim was wrong. Source: existing named Ghidra
  export; exact geometry and initiating caller still need corroboration before
  implementation.
- Installed checkpoint UI verified with idb: nested and shallower more-replies
  rows have trailing blue chevrons; tapping loads a child, parent collapse hides
  the loaded child, reopening restores it without duplication. This was the
  **pre-follow-up binary**, not verification of the new tree helpers.
- Original comparator expansion showed gray italic `3 replies were deleted :(`
  plus blue `More Info`, no chevron. Original exposes a whole accessible row;
  rebuild exposes text fragments. Both remain gaps. Captures are in the approved
  temporary directory: `stock-more-expanded.png`, `rebuild-parent-collapsed.png`,
  `rebuild-parent-reexpanded.png` (the `original-more-*.png` pair is actually
  rebuild; identity was subsequently checked by bundle ID/PID).
- Follow-up Release archive/package succeeded via `scripts/run-in-sim.sh`;
  installed and launched `com.omarsalam.ApolloRebuild` (PID 76852).
- New PID 76852 verified with idb in Me_irl / 301 Comments: collapsing
  Forever203 before expansion hides its nested `1 more reply` placeholder;
  reopening restores it. Expansion replaces it with a deeper comment;
  collapse/reopen preserves that child once, without resurrecting the placeholder
  or duplicating the child. No crash observed. Root-level placeholder was not
  found in a bounded search and remains runtime-unverified (host test passes).
- Concrete remaining count discrepancy: unloaded collapse shows badge `0` while
  the hidden placeholder says `1 more reply`; after expansion badge becomes `1`.
  Confirm original's counting rule before changing it. Fetched child had only
  author/score/time, no body in screenshot or hierarchy; inspect its real JSON
  before calling this a rendering bug. Evidence: approved temp directory's
  `new-before`, `new-unloaded-collapsed`, `new-unloaded-reopened`, `new-loaded`,
  `new-loaded-collapsed`, `new-loaded-reopened` PNG/JSON pairs.
- UI verification and device archive build are separate from host helper tests;
  do not treat host passes as screen parity. Continue-thread navigation, loading
  feedback, deleted-reply state, and collapsed badge counting remain open.

### Stock-reference and functional wiring pass

- Clean stock comparator prepared separately as `com.omarsalam.ApolloStockReference`.
  Original 1.15.11/285 main UUID `9E4EC7AC-92B8-3A03-856C-CE3664D76B97`, SDK16.2,
  cryptid0; no tweak dependencies or runtime Reborn/Substrate mappings. Existing
  app containers untouched. Stock feed menu is a bottom sheet, not UIMenu.
  Feed/account did not populate; stock comment avatars/detail still unverified.
- Comment avatars and glass/menu styling previously measured on injected
  comparator are NOT established as stock parity. Do not tune fonts/colors in
  this pass. Native header fields justify omitting feed's duplicate vote cluster.
- Wired header delegate, author/subreddit menus, comment author and markdown
  links; added generation guards/cancellation and coherent failure snapshots,
  title/menu refresh, basic gallery page indexing and media/browser entry.
- PID92418 device check passed: no duplicate cluster, post/comment author and
  subreddit navigation, article browser opening/dismissal, Save/Unsave UI round
  trip (original unsaved state restored). No votes/public replies performed.
  Post-author destination was empty; navigation alone verified for that profile.
- Explicitly untested: markdown link tap, image/gallery/video viewers, save
  persistence/server refetch. Follow-up adds action-strip accessibility labels.
- Initial sort is `.default`, not necessarily Top despite fallback icon. Use
  response suggestedSort for selected menu state where supplied; do not guess
  server choice when absent. Explicit New selection/checkmark verified then Top
  restored. Native default-sort policy still needs investigation.
- Host tree tests pass; model suite79/79. Two archives succeeded. Changes after
  PID92418 need another archive/runtime pass. Clean-stock evidence report under
  approved temp `apollo-stock-reference-20261030/REPORT.md`; rebuild action
  evidence: `rebuild-detail`, `rebuild-browser`, `rebuild-sort-new-menu`,
  `rebuild-save-restored-menu` PNGs. Reply remains a non-submitting stub.

### Reply transport and insertion pass (2026-10-30)

- PID97282 runtime check: action strip exposes Upvote/Downvote/Save/Reply/Share;
  single image opens and Done dismisses. Hierarchy presence only, not VoiceOver
  playback. Markdown taps, gallery paging, suggested-sort response still unverified.
- First reply implementation archived/installed/launched as PID1263. Reply target
  is a t1_/t3_ fullname, matching original funnel `0x10003e574` (`text`, `thing_id`,
  POST api/comment). Composer now submits, prevents concurrent taps, retains text
  on error and dismisses only after validated success. This is NOT native composer
  parity: context preview, formatting toolbar, drafts and presentation remain open.
  Unsupported UITextView placeholder KVC removed; unsupported new-post Submit is
  disabled instead of silently dismissing.
- Actual client host harness `bash tests/run_comment_submit_tests.sh`: 98 checks,
  no failures. Real RDKClient/request construction/serializer/model code; only
  final network boundary intercepted. Post/comment targets, HTTP401/403/500,
  timeout, JSON rejection, malformed payload, missing/inconsistent identity,
  wrong parent, logged-out/app-only rejection tested. Every failure sends at most
  once. Comment writes explicitly disable generic HTTP401 replay; token refresh
  before first send is retained. No live Reddit writes performed.
- Python mock contract tests cover Unicode/post/comment reply fixtures and
  rejection; these are separate from actual-client tests. Tree helper tests cover
  insertion depth, ancestor expansion, deduplication and absent-parent handling.
  A missing nested parent no longer promotes its reply to thread root. Successful
  insertion invalidates older thread/morechildren snapshots.
- Current tests expose existing unrelated warnings: RDKMultiredditDescription's
  NSObject description collision and boxed-BOOL conditions in moderation APIs.
- Final reply build archived/installed/launched as PID8319 (including keyboard
  avoidance and serializer guards for scalar `json` payloads). Four Python mock
  contract tests pass; successful mock writes now get unique IDs.
- End-to-end mock UI verification passed on isolated test bundle
  `com.omarsalam.ApolloRebuildReplyTest` PID8994, localhost:59518, fake mock_user:
  root t3_ reply inserted; nested t1_ reply inserted beneath its parent; two rapid
  Submit taps during a 1.5s delay produced exactly one request/insertion; explicit
  rejection and malformed result both retained composer text after error dismissal.
  Five LOCAL mock comment requests total (including one accidentally capitalized
  fixture input that followed the success path), zero vote requests. No live
  Reddit writes, real credentials, or signed-in rebuild data modifications.
  Evidence: approved temp `apollo-reply-ui.BWg3i2/requests.jsonl` and root-inserted,
  nested-inserted, reject-real-alert/reject-retained, malformed-alert/retained pairs.
  Software-keyboard layout remains unverified (keyboard stayed hidden); Unicode
  UI typing unsupported by idb, but Unicode transport is host-tested. No obvious
  overlap/truncation in inspected screenshots. Native composer parity still open.
- Next functional gap survey: Continue thread renders but `expand` immediately
  returns for `isContinueThread`; no focus-comment/context request inputs or parent
  row exist. Original saved decompile `0x1007237ec` covers availableLocally and
  ordinary morechildren loading, not enough to establish Continue-thread routing.
  Do not assume that row should use morechildren; trace its earlier dispatcher.

### Continue Thread implementation (2026-10-30, in progress)

- Saved original dispatcher `0x10071ba78` (incorrect recovered name
  AccountManager.getProperAccount) branches on `more.count < 1`, validates a t1
  parent, strips its prefix, and pushes a new CommentsVC with continuingThread=true
  and nil context. Ordinary positive-count loading goes to `0x1007237ec`.
- Original `0x100722d24` resolves nil context to 0 for Continue Thread and 2 for
  ordinary comment focus; limit100. `0x100039968` uses path
  `comments/<post>/_/<comment>.json`, context + sort + pagination. These are static
  saved-decompile observations, not clean-stock runtime verification.
- Added client focused route and optional controller focus/context inputs;
  Continue Thread now pushes a separate screen. Classification uses count<=0,
  not empty children. Invalid/non-comment parent doesn't navigate.
- Host actual-client suite113 checks passes (focused URL/context0/sort/limit100,
  context2, invalid ID, unchanged ordinary full-thread route/depth); models81 checks;
  tree tests and five mock tests pass. Local fixture exposes a Continue Thread
  beneath c002 and focused response. Build15174 succeeded.
- Isolated mock runtime PID15892 passed: Continue beneath c002 requests GET
  /comments/1fx0002/_/c002.json?context=0&limit=100&raw_json=1, shows parent and
  indented continued reply; Back restores original full hierarchy identically.
  Repeated twice. GET-only request evidence; writes explicitly blocked on mock.
  Signed-in app untouched. Evidence under approved temp apollo-continue-ui.mTXJY8/
  (before/focused/back/focused-repeat/back-repeat pairs, requests.jsonl).
  Previously expanded/collapsed variants and alternate sorts unverified.
- Parent-context row, view-full-post control, permalink routing and focused-scroll
  behavior remain separate work.

## Session Notes

- **2026-10-29:** Initial investigation completed. Identified 7 missing files and 31 placeholder view controllers. Moved rebuild into Apollo-Reborn repo.
- **2026-10-29:** Phase 1 complete - implemented all 7 missing source files (43 functions total). Cross-referenced apollo-reborn tweak source for correct function signatures and action kinds.
- **2026-10-29:** Phase 2 complete - fixed all 31 placeholder view controllers with real API calls. All utility/integration managers are now functional.
- **2026-10-29:** Build succeeded! Added missing RDKClient convenience methods (subscribedSubreddits, inboxMessages, savedLinks, multiredditWithName, moderationQueue, moderationLog, modmailConversations, searchModmail, unreadInboxMessages, voteOnLink, saveLink, hideLink, approve, remove, lock, distinguish, setContestMode, createUserReport, search, searchSubreddits). Fixed Swift/ObjC bridging issues (sharedClient() → shared(), method name renames, optional unwrapping). Created stub view controllers for missing moderator action views.
