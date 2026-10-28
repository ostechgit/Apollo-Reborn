// ApolloHideSubredditSections — public surface for the other Subreddits-list
// modules. See the .xm header comment for the full design.

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Number of Random/RandNSFW/CustomFeed pseudo-rows currently appended to the
// END of native section 0 (the feed shortcuts). Code that infers which native
// feed rows exist from -numberOfRowsInSection:0 (Feed Shortcuts' Moderator
// detection in ApolloSubredditIndexPolish.xm) must subtract this first.
NSInteger ApolloHideSubredditSectionsAppendedSection0RowCount(void);

#ifdef __cplusplus
}
#endif
