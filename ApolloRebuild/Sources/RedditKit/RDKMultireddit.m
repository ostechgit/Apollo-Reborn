#import "RDKMultireddit.h"

// RDKMultireddit - Reddit multireddit model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: name (NSString *)
//   +0x10: displayName (NSString *)
//   +0x18: path (NSString *)
//   +0x20: descriptionHTML (NSString *)
//   +0x28: descriptionMarkdown (NSString *)
//   +0x30: copiedFrom (NSString *)
//   +0x38: subreddits (NSArray *)
//   +0x40: isEditable (BOOL)
//   +0x48: visibility (NSString *)
//   +0x50: createdUTC (NSTimeInterval)
//   +0x58: ownerUsername (NSString *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - modelVersion
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - description
//   - username (computed)
//   - subredditsJSONTransformer (Mantle)
//   - visibilityJSONTransformer (Mantle)
//   - createdUTCJSONTransformer (Mantle)
//   - name
//   - displayName
//   - path
//   - descriptionHTML
//   - descriptionMarkdown
//   - copiedFrom
//   - subreddits, - setSubreddits:
//   - isEditable
//   - visibility
//   - createdUTC
//   - ownerUsername, - setOwnerUsername:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKMultireddit

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSUInteger)modelVersion {
    return 1;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"name": @"data.name",
        @"displayName": @"data.display_name",
        @"path": @"data.path",
        @"descriptionHTML": @"data.description_html",
        @"descriptionMarkdown": @"data.description_md",
        @"copiedFrom": @"data.copied_from",
        @"subreddits": @"data.subreddits",
        @"isEditable": @"data.is_editable",
        @"visibility": @"data.visibility",
        @"createdUTC": @"data.created_utc",
        @"ownerUsername": @"data.user",
    };
}

+ (NSValueTransformer *)subredditsJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)visibilityJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)createdUTCJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return @(((NSNumber *)value).doubleValue);} reverseBlock:^id(id value) {
        return @(((NSNumber *)value).doubleValue);
    }];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<RDKMultireddit: %@>", self.name];
}

- (NSString *)username {
    return self.ownerUsername;
}

@end
