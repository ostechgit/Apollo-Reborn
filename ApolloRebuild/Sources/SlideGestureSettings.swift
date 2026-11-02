import Foundation

// SlideGestureSettings - Apollo's configurable swipe actions.
//
// Reconstructed from apollo-base 1.15.11. The original stores five
// `[String]` arrays in `NSUserDefaults.standard`, one per browsing context,
// each holding exactly four action identifiers in `SlideGesturePoint` order:
//
//   first-left, second-left, first-right, second-right
//
// Read path: `FUN_10040e344` (`stringArrayForKey:`), write path: `FUN_10040e700`
// (`setObject:forKey:`). The initial values are seeded from the app's bundled
// `Payload/Apollo.app/Defaults.plist` by `FUN_10040f9a4`; the defaults below are
// copied verbatim from that plist.

/// The four positions a slide gesture can be released at.
///
/// Declaration order is significant: it is the order of the stored array.
/// `first-*` is the shorter drag, `second-*` the longer one.
enum SlideGesturePoint: Int, CaseIterable {
    case firstLeft = 0
    case secondLeft = 1
    case firstRight = 2
    case secondRight = 3

    var rawValueString: String {
        switch self {
        case .firstLeft: return "first-left"
        case .secondLeft: return "second-left"
        case .firstRight: return "first-right"
        case .secondRight: return "second-right"
        }
    }

    /// Row titles from `SettingsGesturesViewController`.
    var title: String {
        switch self {
        case .firstLeft: return "Left Short Swipe"
        case .secondLeft: return "Left Long Swipe"
        case .firstRight: return "Right Short Swipe"
        case .secondRight: return "Right Long Swipe"
        }
    }

    var isLeftward: Bool {
        self == .firstLeft || self == .secondLeft
    }

    /// `true` for the `second-*` (longer) slots, which only fire once the
    /// gesture passes `SlideGestureSettings.longSwipeThreshold`.
    var isLong: Bool {
        self == .secondLeft || self == .secondRight
    }
}

/// The browsing contexts that keep their own swipe configuration.
enum SlideGestureContext: String, CaseIterable {
    case posts = "PostsSlideGestures"
    case comments = "CommentsSlideGestures"
    case inbox = "InboxCommentsSlideGestures"
    case profilePosts = "ProfilePostsSlideGestures"
    case profileComments = "ProfileCommentsSlideGestures"

    var title: String {
        switch self {
        case .posts: return "Posts"
        case .comments: return "Comments"
        case .inbox: return "Inbox Comments"
        case .profilePosts: return "Profile Posts"
        case .profileComments: return "Profile Comments"
        }
    }

    /// Values from `Payload/Apollo.app/Defaults.plist`, in point order.
    var stockDefaults: [SlideGestureAction] {
        switch self {
        case .posts, .profilePosts:
            return [.upvote, .downvote, .reply, .save]
        case .comments:
            return [.upvote, .downvote, .collapseRoot, .reply]
        case .profileComments:
            return [.upvote, .downvote, .save, .reply]
        case .inbox:
            return [.upvote, .downvote, .toggleRead, .reply]
        }
    }
}

/// `SlideGestureAction` - 17 cases, raw values exactly as persisted.
enum SlideGestureAction: String, CaseIterable {
    case upvote
    case unupvote
    case downvote
    case undownvote
    case save
    case unsave
    case collapse
    case collapseRoot = "collapse-root"
    case reply
    case toggleRead = "toggle-read"
    case markRead = "mark-read"
    case markUnread = "mark-unread"
    case post
    case hideAbove = "hide-above"
    case selectMode = "select-mode"
    case parentComment = "parent-comment"
    case moreOptions = "more-options"

    /// Titles from the recovered action-title table
    /// (`kApolloNativeActionDefaultTitles`).
    var title: String {
        switch self {
        case .upvote: return "Upvote"
        case .unupvote: return "Undo Upvote"
        case .downvote: return "Downvote"
        case .undownvote: return "Undo Downvote"
        case .save: return "Save"
        case .unsave: return "Unsave"
        case .collapse: return "Collapse"
        case .collapseRoot: return "Collapse to Top"
        case .reply: return "Reply"
        case .toggleRead: return "Toggle Read"
        case .markRead: return "Mark Read"
        case .markUnread: return "Mark Unread"
        case .post: return "Submit Post"
        case .hideAbove: return "Hide Posts Above"
        case .selectMode: return "Select Mode"
        case .parentComment: return "Parent Comment"
        case .moreOptions: return "More Options"
        }
    }

    /// Asset names from `kApolloNativeActionDefaultAssetNames`.
    var assetName: String {
        switch self {
        case .upvote: return "option-upvote"
        case .unupvote: return "option-undo-upvote"
        case .downvote: return "option-downvote"
        case .undownvote: return "option-undo-downvote"
        case .save: return "option-save"
        case .unsave: return "option-unsave"
        case .collapse: return "option-collapse"
        case .collapseRoot: return "option-collapse-to-top"
        case .reply: return "option-reply"
        case .toggleRead: return "option-read"
        case .markRead: return "option-read"
        case .markUnread: return "option-read"
        case .post: return "option-submit"
        case .hideAbove: return "option-hide"
        case .selectMode: return "option-select-mode"
        case .parentComment: return "option-view-parent"
        case .moreOptions: return "option-more"
        }
    }
}

/// When the long (`second-*`) slot becomes reachable.
enum LongSwipeTriggerPoint: String, CaseIterable {
    case normal
    case later

    var title: String {
        switch self {
        case .normal: return "Normal"
        case .later: return "Later"
        }
    }
}

/// Reads and writes Apollo's slide-gesture defaults.
struct SlideGestureSettings {

    static let triggerPointKey = "LongSwipeGestureTriggerPoint"
    static let disableLeftKey = "DisableLeftSwipeGestureActions"
    static let disableRightKey = "DisableRightSwipeGestureActions"
    static let disableNavigationKey = "DisableNavigationGestures"

    static var store: UserDefaults { UserDefaults.standard }

    // MARK: - Actions

    /// The configured actions for a context, always four entries.
    /// Falls back to the stock array when nothing (or something malformed) is
    /// stored, matching `FUN_10040e344` returning nil and the caller using the
    /// seeded defaults.
    static func actions(for context: SlideGestureContext) -> [SlideGestureAction] {
        guard let raw = store.stringArray(forKey: context.rawValue), raw.count == 4 else {
            return context.stockDefaults
        }
        let parsed = raw.compactMap(SlideGestureAction.init(rawValue:))
        return parsed.count == 4 ? parsed : context.stockDefaults
    }

    static func action(at point: SlideGesturePoint, for context: SlideGestureContext) -> SlideGestureAction {
        return actions(for: context)[point.rawValue]
    }

    static func setAction(_ action: SlideGestureAction, at point: SlideGesturePoint,
                          for context: SlideGestureContext) {
        var current = actions(for: context)
        current[point.rawValue] = action
        store.set(current.map(\.rawValue), forKey: context.rawValue)
    }

    /// "Restore Default Swipe Actions".
    static func restoreDefaults() {
        for context in SlideGestureContext.allCases {
            store.set(context.stockDefaults.map(\.rawValue), forKey: context.rawValue)
        }
        store.set(LongSwipeTriggerPoint.normal.rawValue, forKey: triggerPointKey)
    }

    // MARK: - Trigger point

    static var longSwipeTriggerPoint: LongSwipeTriggerPoint {
        get {
            guard let raw = store.string(forKey: triggerPointKey),
                  let value = LongSwipeTriggerPoint(rawValue: raw) else { return .normal }
            return value
        }
        set { store.set(newValue.rawValue, forKey: triggerPointKey) }
    }

    /// Fraction of the row/cell width a drag must cover for the long slot.
    /// Apollo exposes only "Normal" / "Later"; the exact constants were not
    /// recovered, so these are the two thresholds used here (documented as an
    /// estimate rather than presented as measured).
    static var longSwipeThreshold: CGFloat {
        longSwipeTriggerPoint == .later ? 0.70 : 0.45
    }

    /// A drag shorter than this never fires an action.
    static let minimumSwipeFraction: CGFloat = 0.18

    // MARK: - Direction gates

    static var leftSwipesDisabled: Bool { store.bool(forKey: disableLeftKey) }
    static var rightSwipesDisabled: Bool { store.bool(forKey: disableRightKey) }
}
