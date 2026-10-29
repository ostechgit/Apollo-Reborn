#import "RDKMoreComments.h"

// RDKMoreComments - a "load more comments" placeholder (kind "more")
// Reconstructed from apollo-base 1.15.11 binary analysis.

@implementation RDKMoreComments

+ (NSDictionary<NSString *, id> *)JSONKeyPathsByPropertyKey {
    return [[super JSONKeyPathsByPropertyKey] mtl_dictionaryByAddingEntriesFromDictionary:@{
        @"children": @"data.children",
        @"count": @"data.count",
        @"parentID": @"data.parent_id",
        @"depth": @"data.depth",
    }];
}

- (BOOL)isContinueThread {
    return self.children.count == 0;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<RDKMoreComments: %p; %ld comments under %@>", self, (long)self.count, self.parentID];
}

@end
