#import "RDKThing.h"

// RDKMoreComments - a "load more comments" placeholder (kind "more")
// Reconstructed from apollo-base 1.15.11 binary analysis.

NS_ASSUME_NONNULL_BEGIN

@interface RDKMoreComments : RDKThing

@property (nonatomic, copy, nullable) NSArray<NSString *> *children; // comment IDs to fetch via api/morechildren
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, copy, nullable) NSString *parentID;
@property (nonatomic, assign) NSInteger depth;

// A "continue this thread" link: no IDs to expand inline
@property (nonatomic, readonly) BOOL isContinueThread;

@end

NS_ASSUME_NONNULL_END
