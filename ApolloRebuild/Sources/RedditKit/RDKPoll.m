#import "RDKPoll.h"

// RDKPoll - Reddit poll model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: options (NSArray *)
//   +0x10: totalVoteCount (NSInteger)
//   +0x18: userSelectionIdentifier (NSString *)
//   +0x20: votingEnd (NSDate *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - modelVersion
//   - allowedSecureCodingClassesByPropertyKey
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - votingEndJSONTransformer (Mantle)
//   - optionsJSONTransformer (Mantle)
//   - hasPollEnded (computed)
//   - textualSummary (computed)
//   - options, - setOptions:
//   - totalVoteCount, - setTotalVoteCount:
//   - userSelectionIdentifier, - setUserSelectionIdentifier:
//   - votingEnd, - setVotingEnd:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKPoll

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSUInteger)modelVersion {
    return 1;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"options": @"options",
        @"totalVoteCount": @"total_vote_count",
        @"userSelectionIdentifier": @"user_selection",
        @"votingEnd": @"voting_end",
    };
}

+ (NSValueTransformer *)votingEndJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(NSNumber *value) {
        return [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];} reverseBlock:^id(NSDate *value) {
        return @([value timeIntervalSince1970]);
    }];
}

+ (NSValueTransformer *)optionsJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

- (BOOL)hasPollEnded {
    if (!_votingEnd) {
        return NO;
    }
    return [_votingEnd compare:[NSDate date]] == NSOrderedAscending;
}

- (NSString *)textualSummary {
    if (!_options) {
        return @"";
    }
    
    NSMutableString *summary = [NSMutableString string];
    for (id option in _options) {
        if ([option isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = option;
            NSString *text = dict[@"text"];
            NSNumber *voteCount = dict[@"vote_count"];
            if (text && voteCount) {
                [summary appendFormat:@"%@ (%@)\n", text, voteCount];
            }
        }
    }
    return summary;
}

@end
