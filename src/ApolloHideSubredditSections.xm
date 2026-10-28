#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "ApolloCommon.h"
#import "ApolloHideSubredditSections.h"
#import "UserDefaultConstants.h"

// MARK: - Hide Subreddit Sections
//
// Apollo already has native per-ROW hiding for the Home/Popular/All/Moderator
// Posts pseudo-rows at the top of the Subreddits list (HideRPopularRedditList /
// HideRAllRedditList / HideModeratorRedditList). This module hides whole
// SECTION HEADERS further down the same list -- FAVORITES, MULTIREDDITS, and
// MODERATOR (the grouped list of subreddits you moderate) -- which Apollo has
// no native option for.
//
// Same surgical-filtering discipline as ApolloHideModSubreddits.xm, because the
// same underlying data is read for purposes other than building this one
// screen (mod-power checks, multireddit navigation, per-subreddit favorite-star
// state elsewhere in the app):
//   - RDKUser.moderatedSubreddits getter is filtered ONLY while
//     RedditListViewController's own row-SIZING/BUILDING table methods are on
//     the stack (thread-local depth counter, bumped around %orig). Everywhere
//     else in the app the getter returns the complete, real list -- moderator
//     tools stay intact.
//   - `multireddits` is a *Swift-only* stored property on
//     RedditListViewController -- never bridged to Objective-C at all (proven
//     empirically: class_getInstanceMethod(cls, @selector(multireddits))
//     returns NULL at runtime, meaning Apollo's own Swift code reads it via a
//     direct memory offset, bypassing the ObjC runtime entirely, so there is
//     no method to swizzle). It is a Swift `[RDKMultireddit]?` -- an
//     Optional<Array>, i.e. a VALUE TYPE whose single stored word is a
//     Builtin.BridgeObject (heap pointer + Swift flag bits), NOT an ObjC
//     object reference -- so it must only ever be swapped as a raw word with
//     memcpy, never through object_getIvar/object_setIvar/objc_storeStrong
//     (see the comment on ApolloHideSubredditSectionsSuppressMultiredditsIfNeeded
//     below for the crash history that proved this, and AGENTS.md "Swift
//     Struct Ivars and iOS Version Pitfalls"). The table-sizing/building hooks
//     below temporarily zero the word immediately before each %orig call and
//     restore it immediately after -- tightly bracketed around one synchronous
//     call, so there's no window where anything else could observe or persist
//     the emptied state.
//   - Favorites have no ObjC getter to hook at all either; Apollo stores them
//     as a plain NSUserDefaults array under the (confirmed via `strings` on
//     the binary) native key "FavoriteSubreddits". Hooking NSUserDefaults's
//     -stringArrayForKey:/-objectForKey: and returning an empty array for that
//     one key, under the exact same depth-scoped window, filters it the same
//     way without ever touching the real stored value -- so a subreddit's own
//     favorite-star state (read elsewhere, outside this window) is unaffected,
//     and there's no backup/restore step and no risk of losing a favorite
//     added while the section is hidden.
//
// When moderatedSubreddits/multireddits/FavoriteSubreddits are emptied inside
// that window, RedditListViewController's own section-building logic already
// omits a section with nothing in it entirely from numberOfSectionsInTableView
// (confirmed by ApolloHideModSubreddits.xm's existing comment: "when every
// moderated sub is hidden the section collapses to nothing") -- but that same
// %orig call is NOT itself filtered (it isn't hooked at all), so it still
// counts the section as existing with an empty header. heightForHeaderInSection:
// and viewForHeaderInSection: are filtered the same way as the row methods
// below so that empty section's header collapses to nothing too, instead of
// showing a header with zero rows under it.
//
// Hidden section kinds are stored in UDKeyHiddenSubredditIndexSections (see
// UserDefaultConstants.h) as a flat array of strings, a subset of
// {"Favorites", "Multireddits", "Moderator"}.
//
// MARK: - Random/RandNSFW/CustomFeed pseudo-rows
//
// UDKeyShowRandomInSubredditsList / UDKeyShowRandNsfwInSubredditsList /
// UDKeyShowCustomFeedInSubredditsList append "Random"/"RandNSFW"/"CustomFeed"
// as extra rows at the END of the EXISTING top pseudo-row section (physical
// section 0 -- Home/Popular/All/Moderator Posts), rather than requiring any
// of them to be manually favorited, and rather than standing up a whole new
// section with its own header (an earlier version of this feature did
// exactly that; it needed section-index remapping across every other
// section, a fake inserted header that had to be relabeled from Apollo's
// borrowed "FAVORITES" title, and an A-Z jump-bar index shift -- all of which
// goes away once these are just more rows in the section that already
// exists and already has no header). Enabled independently -- if enabled,
// show it; if disabled, hide it, matching Apollo's own native per-pseudo-row
// toggles in that same section. CustomFeed is injected unconditionally the
// same way as Random/RandNSFW -- it does not require the combined feed's
// underlying subreddits to be followed/subscribed.
//
// Cell APPEARANCE is built directly (ApolloHideSubredditSectionsBuildPseudoRowCell,
// below) as an Apollo.ApolloSubtitleTableViewCell -- the exact class the other
// pseudo-rows in this section use -- with a hand-drawn colored-circle glyph, so
// these rows look like siblings of Home/Popular/All/Moderator Posts, not
// like a favorited subreddit (no star control, no failed icon-fetch for a
// subreddit that doesn't exist).
//
// NAVIGATION still has no direct path: there is no ObjC-callable "open
// subreddit by name" method (confirmed via the full method list on
// _TtC6Apollo24RedditListViewController), so didSelectRowAtIndexPath: reuses
// Apollo's OWN real Favorites-row push logic by BORROWING it: the
// NSUserDefaults hook below can make "FavoriteSubreddits" appear to contain
// ONLY ["Random", "RandNSFW", "CustomFeed"] (filtered by which toggle is on)
// for the exact duration of one %orig call targeting Apollo's own native
// section 1 (which Apollo always treats as FAVORITES when non-empty, per the
// existing empirically-confirmed section ordering). Apollo then navigates
// exactly as it would for tapping a real favorited subreddit named "Random"
// -- with zero custom navigation code, and without ever touching the user's
// actual favorites (the shadow is active only around that one call; the real
// getter, and the real Favorites section rendering elsewhere in the SAME
// table reload, are completely unaffected). This is the same technique as
// the Multireddits ivar-swap above, just substituting fake content instead
// of emptying real content -- now used for navigation only, not cell
// building.
//
// Apollo's own numberOfRowsInSection: for physical section 0 is queried by
// UIKit before cellForRowAtIndexPath:/didSelectRowAtIndexPath: for the same
// reload pass, so the native (pre-append) row count is cached in a thread-local
// the moment it's computed, and read back by the row/select hooks below to
// tell a real pseudo-row index apart from one of our appended ones.

@interface RDKUser : NSObject
- (NSArray *)moderatedSubreddits;
@end

// Hooked by its mangled name, not the bare "RedditListViewController": bare
// Swift class names can silently fail to resolve at hook-install time under
// the simulator's internal Logos generator (confirmed elsewhere in this
// codebase -- see AGENTS.md "Hooking a Lazily-Realized Swift Class"). The
// mangled name resolves via a compile-time-bound symbol instead.
@interface _TtC6Apollo24RedditListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@end

// Thread-local nesting depth of "we are currently inside a Subreddits-list
// table method that reads multireddits/moderatedSubreddits/FavoriteSubreddits
// for display." Filtering only applies when this is > 0, so every other
// reader (mod-power checks, multireddit navigation, favorite-star state,
// background work, any other thread) sees the real, complete data.
static __thread NSInteger sSectionFilterDepth = 0;

// Resolved once at ctor time. `multireddits` has no ObjC getter (see the
// header comment above), so this is the only way to read/write it.
static Ivar sMultiredditsIvar = NULL;

// Thread-local nesting depth of "we are currently borrowing Apollo's real
// Favorites-row code to render/navigate one of OUR appended
// Random/RandNSFW/CustomFeed pseudo-rows." While this is > 0, the
// NSUserDefaults hook below substitutes
// fake content for "FavoriteSubreddits" reads -- see the MARK comment above
// for why.
static __thread NSInteger sRandomShadowDepth = 0;

// Apollo's own native row count for physical section 0, cached the moment our
// numberOfRowsInSection: hook computes it (UIKit always queries row count for
// a section before requesting cells/selections within it for the same reload
// pass). -1 means "not yet known this pass" -- callers must treat that as "no
// appended row could possibly be in range" rather than guessing.
static __thread long long sSection0NativeRowCount = -1;

static NSSet<NSString *> *ApolloHiddenSubredditIndexSectionsSet(void) {
    NSArray<NSString *> *hidden = [[NSUserDefaults standardUserDefaults] stringArrayForKey:UDKeyHiddenSubredditIndexSections];
    return hidden.count > 0 ? [NSSet setWithArray:hidden] : nil;
}

static BOOL ApolloHiddenSubredditIndexSectionIsHidden(NSString *kind) {
    return [ApolloHiddenSubredditIndexSectionsSet() containsObject:kind];
}

// Filtered content for the appended Random/RandNSFW/CustomFeed pseudo-rows --
// whichever are individually turned on, in display order.
static NSArray<NSString *> *ApolloHideSubredditSectionsRandomItems(void) {
    NSMutableArray<NSString *> *items = [NSMutableArray array];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:UDKeyShowRandomInSubredditsList]) [items addObject:@"Random"];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:UDKeyShowRandNsfwInSubredditsList]) [items addObject:@"RandNSFW"];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:UDKeyShowCustomFeedInSubredditsList]) [items addObject:@"CustomFeed"];
    return items;
}

NSInteger ApolloHideSubredditSectionsAppendedSection0RowCount(void) {
    return (NSInteger)ApolloHideSubredditSectionsRandomItems().count;
}

// The `multireddits` ivar is NOT an ObjC object reference and must never be
// touched with ObjC ownership primitives. It is a Swift `[RDKMultireddit]?` --
// an Optional<Array>, whose single stored word is a Builtin.BridgeObject:
// the array-storage heap pointer with Swift discriminator FLAG BITS OR'd in.
// Confirmed live in the simulator: the stored word is 0x4000000103f7cad0 --
// bit 62 (0x4000000000000000, Swift's native-storage flag on arm64) set on
// top of the real pointer 0x103f7cad0.
//
// That flagged word is exactly why the two earlier implementations crashed:
// object_getIvar / objc_storeStrong both hand the word to ARC as an `id`, and
// ARC retains/autoreleases it. objc's tagged-pointer check on arm64 looks at
// bit 63 only, so a bit-62-flagged word is treated as a REAL object pointer.
// The poisoned autorelease pool then pops at the end of the launch
// scene-creation callout and objc_release dereferences the flagged address:
// EXC_BAD_ACCESS in AutoreleasePoolPage::releaseUntil -> objc_release, which
// is the exact crashed-thread stack in all four device .ips reports (and was
// reproduced identically in the simulator). The swap-site logging always
// looked clean because the corruption isn't at the swap -- it's the flagged
// word sitting in the autorelease pool, released later.
//
// The safe approach used here: swap the raw WORD with memcpy and perform NO
// reference-counting operations at all. Net refcount effect is zero by
// construction: the word is copied out, zeroed (0 == nil for Optional<Array>,
// a state Apollo's own Swift code handles routinely -- it's the pre-fetch
// value), %orig runs synchronously on the same thread, and the identical word
// is copied back. Nothing inside the bracket writes the ivar (verified by the
// earlier race-check diagnostic build: the slot is always still nil right
// before restore), and ARC never sees the word because it stays a uintptr_t.
static uintptr_t ApolloHideSubredditSectionsSuppressMultiredditsIfNeeded(id viewController) {
    if (!sMultiredditsIvar || !ApolloHiddenSubredditIndexSectionIsHidden(@"Multireddits")) return 0;
    uint8_t *slot = (uint8_t *)(__bridge void *)viewController + ivar_getOffset(sMultiredditsIvar);
    uintptr_t saved = 0;
    memcpy(&saved, slot, sizeof(saved));
    if (saved == 0) return 0;
    uintptr_t zero = 0;
    memcpy(slot, &zero, sizeof(zero));
    return saved;
}

static void ApolloHideSubredditSectionsRestoreMultireddits(id viewController, uintptr_t saved) {
    if (saved == 0 || !sMultiredditsIvar) return;
    uint8_t *slot = (uint8_t *)(__bridge void *)viewController + ivar_getOffset(sMultiredditsIvar);
    memcpy(slot, &saved, sizeof(saved));
}

// Apollo's own native storage key for favorited subreddits (confirmed via
// `strings` on the Apollo binary: FavoriteSubreddits / FavoriteSubredditsUpdated
// / com.christianselig.FavoriteSubredditsUpdated / favoriteSubredditButtonTapped:).
// Not a key this tweak invented.
static NSString *const kApolloNativeFavoriteSubredditsKey = @"FavoriteSubreddits";

// The Home/Popular/All Posts/Moderator Posts pseudo-rows in this same section
// are Apollo.ApolloSubtitleTableViewCell -- confirmed via
// ApolloModeratorAvatars.xm's own header comment and ApolloSubredditIndexPolish.xm's
// -layoutSubviews hook on that exact class, both of which use plain
// UITableViewCell API (cell.imageView/.textLabel/.detailTextLabel), since the
// class adds no custom ivars of its own. Building our appended rows as
// instances of this SAME class (rather than continuing to borrow Apollo's real
// favorited-subreddit cell, which is a different class --
// _TtC6Apollo23RedditListTableViewCell, a stack-view layout with its own
// subredditIcon/accessoryButton ivars and the star control we don't want here)
// gets pixel-identical styling for free, with zero custom layout code.
static Class ApolloHideSubredditSectionsPseudoRowCellClass(void) {
    static Class cls;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cls = objc_getClass("_TtC6Apollo27ApolloSubtitleTableViewCell");
    });
    return cls;
}

// Hand-drawn colored-circle glyph, matching the existing pattern in
// ApolloHideModSubreddits.xm's ApolloHideModGlyph() -- there's no bundled or
// native asset for a "random subreddit"/"custom feed" icon to reuse
// (confirmed: no shuffle/dice/layers asset anywhere in this repo, and the
// native pseudo-row icons are drawn entirely inside stripped Swift with no
// ObjC-visible access point), so this draws one the same way: a flat tinted
// circle with a white SF Symbol glyph centered on top.
static UIImage *ApolloHideSubredditSectionsGlyphForItem(NSString *name) {
    static NSMutableDictionary<NSString *, UIImage *> *sGlyphCache = nil;
    if (!sGlyphCache) sGlyphCache = [NSMutableDictionary dictionary];
    UIImage *cached = sGlyphCache[name];
    if (cached) return cached;

    BOOL nsfw = [name isEqualToString:@"RandNSFW"];
    BOOL customFeed = [name isEqualToString:@"CustomFeed"];
    UIColor *fillColor = nsfw ? [UIColor systemOrangeColor] : (customFeed ? [UIColor systemTealColor] : [UIColor systemPurpleColor]);
    NSString *symbolName = customFeed ? @"square.stack.3d.up.fill" : @"shuffle";

    CGFloat diameter = 29.0;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightBold];
    UIImage *symbol = [[UIImage systemImageNamed:symbolName] imageByApplyingSymbolConfiguration:config];
    symbol = [symbol imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(diameter, diameter)];
    UIImage *drawn = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [fillColor setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, diameter, diameter)] fill];
        if (symbol) {
            CGSize symSize = symbol.size;
            CGRect symRect = CGRectMake((diameter - symSize.width) / 2.0, (diameter - symSize.height) / 2.0, symSize.width, symSize.height);
            [symbol drawInRect:symRect];
        }
    }];
    UIImage *result = [drawn imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    sGlyphCache[name] = result;
    return result;
}

// Builds a section-0-styled cell directly -- no borrowing, no star accessory,
// no icon-fetch attempt for a subreddit that doesn't exist. Navigation still
// goes through the borrow-shadow trick (in didSelectRowAtIndexPath: below);
// only cell APPEARANCE needed to stop coming from the borrowed Favorites cell.
static UITableViewCell *ApolloHideSubredditSectionsBuildPseudoRowCell(NSString *name) {
    Class cellClass = ApolloHideSubredditSectionsPseudoRowCellClass() ?: [UITableViewCell class];
    UITableViewCell *cell = [[cellClass alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    NSString *subtitle;
    if ([name isEqualToString:@"RandNSFW"]) {
        subtitle = @"Random NSFW subreddit";
    } else if ([name isEqualToString:@"CustomFeed"]) {
        subtitle = @"Custom combined feed";
    } else {
        subtitle = @"Random subreddit";
    }
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.textLabel.text = name;
    cell.detailTextLabel.text = subtitle;
    cell.imageView.image = ApolloHideSubredditSectionsGlyphForItem(name);
    return cell;
}

%ctor {
    Class cls = objc_getClass("_TtC6Apollo24RedditListViewController");
    sMultiredditsIvar = cls ? class_getInstanceVariable(cls, "multireddits") : NULL;
    if (!sMultiredditsIvar) {
        ApolloLog(@"[HideSubSections] could not resolve RedditListViewController.multireddits ivar; Multireddits section hiding will be a no-op");
    }
}

%hook RDKUser

// Short-circuits BEFORE the existing per-item hidden-list filter in
// ApolloHideModSubreddits.xm when the whole section is hidden (an empty
// section trivially subsumes any per-item hide list), and otherwise defers to
// %orig unchanged -- so the existing per-item hiding feature is untouched when
// this master toggle is off, and stays correct even if which subreddits you
// moderate changes later (this re-checks live on every call, not a snapshot).
- (NSArray *)moderatedSubreddits {
    if (sSectionFilterDepth > 0 && ApolloHiddenSubredditIndexSectionIsHidden(@"Moderator")) {
        return @[];
    }
    return %orig;
}

// NOTE: RDKUser also exposes `multireddits` as an ObjC property
// (Headers/ObjC/RDKUser.h), which would have allowed the same proven
// depth-scoped getter filter used for moderatedSubreddits above -- but a
// diagnostic probe confirmed the Subreddits list's table build never calls
// that getter (it only ever fired at depth 0); the section is built from the
// view controller's own Swift ivar, hence the raw-word swap above.

%end

%hook NSUserDefaults

// Shadow substitution (borrowing Apollo's real Favorites-row code for our
// appended pseudo-rows) always takes priority over the ordinary hide-filter:
// the two are temporally disjoint in practice (never both meaningful for the
// same %orig call), but checking shadow first makes that an invariant rather
// than an assumption.
- (NSArray *)stringArrayForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:kApolloNativeFavoriteSubredditsKey]) {
        if (sRandomShadowDepth > 0) return ApolloHideSubredditSectionsRandomItems();
        if (sSectionFilterDepth > 0 && ApolloHiddenSubredditIndexSectionIsHidden(@"Favorites")) return @[];
    }
    return %orig;
}

- (id)objectForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:kApolloNativeFavoriteSubredditsKey]) {
        if (sRandomShadowDepth > 0) return ApolloHideSubredditSectionsRandomItems();
        if (sSectionFilterDepth > 0 && ApolloHiddenSubredditIndexSectionIsHidden(@"Favorites")) return @[];
    }
    return %orig;
}

// Swift's `UserDefaults.array(forKey:)` (distinct from `.stringArray(forKey:)`)
// bridges to this selector -- covering it in case Apollo reads the favorites
// list through this typed accessor instead of the other two.
- (NSArray *)arrayForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:kApolloNativeFavoriteSubredditsKey]) {
        if (sRandomShadowDepth > 0) return ApolloHideSubredditSectionsRandomItems();
        if (sSectionFilterDepth > 0 && ApolloHiddenSubredditIndexSectionIsHidden(@"Favorites")) return @[];
    }
    return %orig;
}

%end

%hook _TtC6Apollo24RedditListViewController

- (long long)tableView:(UITableView *)tableView numberOfRowsInSection:(long long)section {
    uintptr_t savedMultireddits = ApolloHideSubredditSectionsSuppressMultiredditsIfNeeded(self);
    sSectionFilterDepth++;
    long long result = %orig;
    sSectionFilterDepth--;
    ApolloHideSubredditSectionsRestoreMultireddits(self, savedMultireddits);
    if (section == 0) {
        sSection0NativeRowCount = result;
        result += (long long)ApolloHideSubredditSectionsRandomItems().count;
    }
    return result;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(long long)section {
    uintptr_t savedMultireddits = ApolloHideSubredditSectionsSuppressMultiredditsIfNeeded(self);
    sSectionFilterDepth++;
    CGFloat result = %orig;
    sSectionFilterDepth--;
    ApolloHideSubredditSectionsRestoreMultireddits(self, savedMultireddits);
    return result;
}

- (id)tableView:(UITableView *)tableView viewForHeaderInSection:(long long)section {
    uintptr_t savedMultireddits = ApolloHideSubredditSectionsSuppressMultiredditsIfNeeded(self);
    sSectionFilterDepth++;
    UIView *header = %orig;
    sSectionFilterDepth--;
    ApolloHideSubredditSectionsRestoreMultireddits(self, savedMultireddits);
    return header;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && sSection0NativeRowCount >= 0 && indexPath.row >= sSection0NativeRowCount) {
        NSInteger extraRow = indexPath.row - sSection0NativeRowCount;
        NSArray<NSString *> *items = ApolloHideSubredditSectionsRandomItems();
        if ((NSUInteger)extraRow >= items.count) return [UITableViewCell new];
        return ApolloHideSubredditSectionsBuildPseudoRowCell(items[extraRow]);
    }
    uintptr_t savedMultireddits = ApolloHideSubredditSectionsSuppressMultiredditsIfNeeded(self);
    sSectionFilterDepth++;
    UITableViewCell *cell = %orig;
    sSectionFilterDepth--;
    ApolloHideSubredditSectionsRestoreMultireddits(self, savedMultireddits);
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && sSection0NativeRowCount >= 0 && indexPath.row >= sSection0NativeRowCount) {
        NSInteger extraRow = indexPath.row - sSection0NativeRowCount;
        NSArray<NSString *> *items = ApolloHideSubredditSectionsRandomItems();
        if ((NSUInteger)extraRow >= items.count) return;
        sRandomShadowDepth++;
        sSectionFilterDepth++;
        %orig(tableView, [NSIndexPath indexPathForRow:extraRow inSection:1]);
        sSectionFilterDepth--;
        sRandomShadowDepth--;
        return;
    }
    uintptr_t savedMultireddits = ApolloHideSubredditSectionsSuppressMultiredditsIfNeeded(self);
    sSectionFilterDepth++;
    %orig;
    sSectionFilterDepth--;
    ApolloHideSubredditSectionsRestoreMultireddits(self, savedMultireddits);
}

%end
