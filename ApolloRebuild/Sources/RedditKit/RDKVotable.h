#import "RDKCreated.h"

// RDKVotable - a thing that can be voted on (links and comments)
// Reconstructed from apollo-base 1.15.11 binary analysis.

NS_ASSUME_NONNULL_BEGIN

// Stored state, from data.likes (true / false / null)
typedef NS_ENUM(NSUInteger, RDKVoteStatus) {
    RDKVoteStatusNone = 0,
    RDKVoteStatusUpvoted = 1,
    RDKVoteStatusDownvoted = 2,
};

// Values passed to -[RDKClient voteOnThingWithFullName:direction:completion:].
// The original maps them through a table to api/vote's dir: 1 -> "1", 2 -> "-1", 3 -> "0".
typedef NS_ENUM(NSInteger, RDKVoteDirection) {
    RDKVoteDirectionUp = 1,
    RDKVoteDirectionDown = 2,
    RDKVoteDirectionNone = 3,
};

@interface RDKVotable : RDKCreated

@property (nonatomic, assign) NSInteger upvotes;      // data.ups
@property (nonatomic, assign) NSInteger downvotes;    // data.downs
@property (nonatomic, assign) NSInteger score;        // data.score
@property (nonatomic, assign) RDKVoteStatus voteStatus; // data.likes

@property (nonatomic, readonly) BOOL upvoted;
@property (nonatomic, readonly) BOOL downvoted;
@property (nonatomic, readonly) BOOL voted;

@end

NS_ASSUME_NONNULL_END
