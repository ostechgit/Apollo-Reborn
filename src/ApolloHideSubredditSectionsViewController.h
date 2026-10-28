#import <UIKit/UIKit.h>

// "Hide Subreddit Sections" management screen -- mirrors Apollo's own native
// "Hide Subreddits Row" screen (Settings > General > Hide Subreddits Row):
// a dedicated list of hideable items with per-item toggles, so a hidden
// section can be re-enabled from the same place it was hidden.
@interface ApolloHideSubredditSectionsViewController : UITableViewController
@end
