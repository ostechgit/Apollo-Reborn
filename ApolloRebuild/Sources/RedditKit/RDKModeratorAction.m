#import "RDKModeratorAction.h"

// RDKModeratorAction - Reddit moderator action model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: fullName (NSString *)
//   +0x10: action (NSString *)
//   +0x18: details (NSString *)
//   +0x20: moderatorUsername (NSString *)
//   +0x28: moderatorIdentifier (NSString *)
//   +0x30: subredditName (NSString *)
//   +0x38: subredditIdentifier (NSString *)
//   +0x40: targetFullName (NSString *)
//   +0x48: targetPermalink (NSString *)
//   +0x50: targetAuthor (NSString *)
//   +0x58: targetTitle (NSString *)
//   +0x60: targetBody (NSString *)
//   +0x68: modDescription (NSString *)
//
// Methods recovered:
//   - JSONKeyPathsByPropertyKey (Mantle: extends RDKCreated with action, details, moderatorUsername, etc.)
//   - description
//   - targetPermalinkJSONTransformer (Mantle)
//   - fullName
//   - action, - setAction:
//   - details, - setDetails:
//   - moderatorUsername, - setModeratorUsername:
//   - moderatorIdentifier, - setModeratorIdentifier:
//   - subredditName, - setSubredditName:
//   - subredditIdentifier, - setSubredditIdentifier:
//   - targetFullName, - setTargetFullName:
//   - targetPermalink, - setTargetPermalink:
//   - targetAuthor, - setTargetAuthor:
//   - targetTitle, - setTargetTitle:
//   - targetBody, - setTargetBody:
//   - modDescription, - setModDescription:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKModeratorAction

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    NSDictionary *base = [super JSONKeyPathsByPropertyKey];
    return [base mtl_dictionaryByAddingEntriesFromDictionary:@{
        @"action": @"data.action",
        @"details": @"data.details",
        @"modDescription": @"data.description",
        @"moderatorIdentifier": @"data.mod_id36",
        @"moderatorUsername": @"data.mod",
        @"subredditIdentifier": @"data.sr_id36",
        @"subredditName": @"data.subreddit",
        @"targetAuthor": @"data.target_author",
        @"targetBody": @"data.target_body",
        @"targetFullName": @"data.target_fullname",
        @"targetPermalink": @"data.target_permalink",
        @"targetTitle": @"data.target_title",
    }];
}

+ (NSValueTransformer *)targetPermalinkJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<RDKModeratorAction: %@ by %@>", self.action, self.moderatorUsername];
}

@end
