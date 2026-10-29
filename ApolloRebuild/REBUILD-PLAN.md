# Apollo Base Rebuild Plan

**Goal:** Achieve a perfect 1:1 match with apollo-base.ipa 1.15.11 (build 285). UI/UX and functionality should be 100% identical to the original.

**Target Binary:** `/Users/omarsalam/Projects/Apollo-Reborn/Apollo-base.ipa` (sha256: 9526010ba4c52a5d1ad608f2c0262cefcb0d0740e8a960362642cbaec8b62f40)

**RE Artifacts:** `~/Projects/Apollo-Source-Private/` - 53,316 decompiled functions, 7,806 recovered names, naming pipeline complete.

## Status: In Progress

Last updated: 2026-10-29

## Phase 1: Implement Missing Source Files (7 files, 43 functions)

### Priority 1: ActionController+Moderator.swift (33 functions)
- **Status:** Not started
- **Purpose:** Moderator actions for comments (approve, remove, stick, lock, etc.)
- **Functions to implement:**
  - `showModeratorActions(forComment:sectionController:viewController:completion:)`
  - And 32 more moderator action functions
- **Cross-reference:** Check apollo-reborn's `src/ApolloActionMenu.xm` for hook names

### Priority 2: AppDelegate+Notifications.swift (4 functions)
- **Status:** Not started
- **Purpose:** APNs token handling for push notifications
- **Functions to implement:**
  - `fetchAPNsToken(completion:)`
  - `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`
  - `application(_:didFailToRegisterForRemoteNotificationsWithError:)`
- **Cross-reference:** Check apollo-reborn's notification hooks

### Priority 3: Holla.swift (2 functions)
- **Status:** Not started
- **Purpose:** Status toast notifications
- **Functions to implement:**
  - `showStatus(_:text:duration:savedItemFullName:fromViewController:tappedBlock:)`
  - `HollaSavedItemStatusView` class
- **Cross-reference:** Check apollo-reborn's toast implementation

### Priority 4: ASTableViewController.swift (1 function)
- **Status:** Not started
- **Purpose:** Base table view controller with viewDidAppear
- **Functions to implement:**
  - `viewDidAppear(_:)`
- **Cross-reference:** Check apollo-reborn's table view hooks

### Priority 5: ActionController+UserReport.swift (2 functions)
- **Status:** Not started
- **Purpose:** User reporting functionality
- **Functions to implement:**
  - `normalUserReportSubredditRulesSelected(thingFullname:subreddit:tintAsModerator:fromViewController:)`
  - And 1 more
- **Cross-reference:** Check apollo-reborn's report hooks

### Priority 6: ActionController+ModmailReport.swift (1 function)
- **Status:** Not started
- **Purpose:** Modmail reporting
- **Functions to implement:**
  - `modmailReportSubredditRulesSelected(thingFullname:subreddit:tintAsModerator:fromViewController:)`
- **Cross-reference:** Check apollo-reborn's modmail report hooks

### Priority 7: ActionController+Report.swift (1 function)
- **Status:** Not started
- **Purpose:** General post/comment reporting
- **Functions to implement:**
  - `reportSubredditRulesSelected(thingFullname:subreddit:tintAsModerator:fromViewController:)`
- **Cross-reference:** Check apollo-reborn's report hooks

## Phase 2: Fix Placeholder View Controllers (31 files)

### Priority 1: Core Navigation
- **RedditListViewController.swift** - Subreddit list (currently placeholder)
- **SearchViewController.swift** - Search results (currently placeholder)
- **MultiredditViewController.swift** - Multireddit posts (currently placeholder)

### Priority 2: User Content
- **InboxViewController.swift** - Messages (currently placeholder)
- **NotificationsViewController.swift** - Notifications (currently placeholder)
- **SavedPostsCommentsViewController.swift** - Saved items (currently placeholder)
- **AllSubredditCommentsViewController.swift** - All comments for subreddit (currently placeholder)

### Priority 3: Search Results
- **PostsSearchResultsViewController.swift** - Post search results (currently placeholder)
- **SubredditSearchResultsViewController.swift** - Subreddit search results (currently placeholder)
- **ModmailSearchResultsViewController.swift** - Modmail search results (currently placeholder)

### Priority 4: Moderation
- **ModQueueViewController.swift** - Mod queue (currently placeholder)
- **ModeratorLogsViewController.swift** - Mod logs (currently placeholder)
- **ModmailInboxViewController.swift** - Modmail inbox (currently placeholder)

### Priority 5: Utility/Integration
- **GfycatClient.swift** - Gfycat API client (currently placeholder)
- **ImgurClient.swift** - Imgur API client (currently placeholder)
- **WikipediaClient.swift** - Wikipedia API client (currently placeholder)
- **WeatherManager.swift** - Weather API client (currently placeholder)
- **ReceiptDataBuddy.swift** - App Store receipt data (currently placeholder)
- **AppStoreBuddy.swift** - App Store integration (currently placeholder)
- **AstraAnalyticsManager.swift** - Analytics (currently placeholder)
- **AstraCrashReporter.swift** - Crash reporting (currently placeholder)
- **AstraNetworkManager.swift** - Network management (currently placeholder)
- **AstraNotificationManager.swift** - Notification management (currently placeholder)
- **AstraThemeManager.swift** - Theme management (currently placeholder)
- **AstraUpdateManager.swift** - Update management (currently placeholder)
- **EasterSaleManager.swift** - Easter sale feature (currently placeholder)
- **ApollonouncementHelper.swift** - Announcements (currently placeholder)
- **PostCellActionTaker.swift** - Post cell actions (currently placeholder)
- **ThemeManager.swift** - Theme management (currently placeholder)
- **RefundScreenHelper.swift** - Refund screen (currently placeholder)
- **TipJar2ViewController.swift** - Tip jar feature (currently placeholder)
- **LiveActivityHelper.swift** - Live Activities (currently placeholder)

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

- 7 original source files missing from rebuild
- 31 view controllers use placeholder data instead of real API calls
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

## Session Notes

- **2026-10-29:** Initial investigation completed. Identified 7 missing files and 31 placeholder view controllers. Moved rebuild into Apollo-Reborn repo.
