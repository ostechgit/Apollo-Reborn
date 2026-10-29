#import "RDKPollOption.h"

// RDKPollOption - Reddit poll option model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: identifier (NSString *)
//   +0x10: text (NSString *)
//   +0x18: voteCount (NSInteger)
//
// Methods recovered:
//   - modelVersion
//   - supportsSecureCoding
//   - JSONKeyPathsByPropertyKey (Mantle: identifier -> id, text -> text, voteCount -> vote_count)
//   - identifier, - setIdentifier:
//   - text, - setText:
//   - voteCount, - setVoteCount:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKPollOption

+ (NSUInteger)modelVersion {
    return 1;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"identifier": @"id",
        @"text": @"text",
        @"voteCount": @"vote_count",
    };
}

@end
