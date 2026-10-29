#import "RDKVotable.h"

// RDKVotable - a thing that can be voted on
// Reconstructed from apollo-base 1.15.11 binary analysis.

@implementation RDKVotable

+ (NSDictionary<NSString *, id> *)JSONKeyPathsByPropertyKey {
    return [[super JSONKeyPathsByPropertyKey] mtl_dictionaryByAddingEntriesFromDictionary:@{
        @"upvotes": @"data.ups",
        @"downvotes": @"data.downs",
        @"score": @"data.score",
        @"voteStatus": @"data.likes",
    }];
}

+ (NSValueTransformer *)voteStatusJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSNumber *likes, BOOL *success, NSError **error) {
        if (![likes isKindOfClass:[NSNumber class]]) {
            return @(RDKVoteStatusNone);
        }
        return @(likes.boolValue ? RDKVoteStatusUpvoted : RDKVoteStatusDownvoted);
    } reverseBlock:^id(NSNumber *status, BOOL *success, NSError **error) {
        switch (status.unsignedIntegerValue) {
            case RDKVoteStatusUpvoted: return @YES;
            case RDKVoteStatusDownvoted: return @NO;
            default: return nil;
        }
    }];
}

- (BOOL)upvoted {
    return self.voteStatus == RDKVoteStatusUpvoted;
}

- (BOOL)downvoted {
    return self.voteStatus == RDKVoteStatusDownvoted;
}

- (BOOL)voted {
    return self.voteStatus != RDKVoteStatusNone;
}

@end
