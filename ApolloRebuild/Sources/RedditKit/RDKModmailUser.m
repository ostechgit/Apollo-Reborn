#import "RDKModmailUser.h"

// RDKModmailUser - Reddit modmail user model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: banStatus (id)
//   +0x10: created (NSDate *)
//   +0x18: identifier (NSString *)
//   +0x20: isShadowBanned (BOOL)
//   +0x28: isSuspended (BOOL)
//   +0x30: muteStatus (id)
//   +0x38: name (NSString *)
//   +0x40: recentComments (NSArray *)
//   +0x48: recentConvos (NSArray *)
//   +0x50: recentPosts (NSArray *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - initWithCoder:
//   - encodeWithCoder:
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - recentPostsJSONTransformer (Mantle)
//   - recentCommentsJSONTransformer (Mantle)
//   - recentConvosJSONTransformer (Mantle)
//   - createdJSONTransformer (Mantle)
//   - banStatusJSONTransformer (Mantle)
//   - muteStatusJSONTransformer (Mantle)
//   - banStatus, - setBanStatus:
//   - created, - setCreated:
//   - identifier, - setIdentifier:
//   - isShadowBanned, - setIsShadowBanned:
//   - isSuspended, - setIsSuspended:
//   - muteStatus, - setMuteStatus:
//   - name, - setName:
//   - recentComments, - setRecentComments:
//   - recentConvos, - setRecentConvos:
//   - recentPosts, - setRecentPosts:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKModmailUser

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"banStatus": @"ban_status",
        @"created": @"created",
        @"identifier": @"id",
        @"isShadowBanned": @"is_shadowbanned",
        @"isSuspended": @"is_suspended",
        @"muteStatus": @"mute_status",
        @"name": @"name",
        @"recentComments": @"recent_comments",
        @"recentConvos": @"recent_convos",
        @"recentPosts": @"recent_posts",
    };
}

+ (NSValueTransformer *)recentPostsJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)recentCommentsJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)recentConvosJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)createdJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(NSNumber *value) {
        return [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];} reverseBlock:^id(NSDate *value) {
        return @([value timeIntervalSince1970]);
    }];
}

+ (NSValueTransformer *)banStatusJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)muteStatusJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _banStatus = [coder decodeObjectForKey:@"banStatus"];
        _created = [coder decodeObjectForKey:@"created"];
        _identifier = [coder decodeObjectForKey:@"identifier"];
        _isShadowBanned = [coder decodeBoolForKey:@"isShadowBanned"];
        _isSuspended = [coder decodeBoolForKey:@"isSuspended"];
        _muteStatus = [coder decodeObjectForKey:@"muteStatus"];
        _name = [coder decodeObjectForKey:@"name"];
        _recentComments = [coder decodeObjectForKey:@"recentComments"];
        _recentConvos = [coder decodeObjectForKey:@"recentConvos"];
        _recentPosts = [coder decodeObjectForKey:@"recentPosts"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_banStatus forKey:@"banStatus"];
    [coder encodeObject:_created forKey:@"created"];
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeBool:_isShadowBanned forKey:@"isShadowBanned"];
    [coder encodeBool:_isSuspended forKey:@"isSuspended"];
    [coder encodeObject:_muteStatus forKey:@"muteStatus"];
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_recentComments forKey:@"recentComments"];
    [coder encodeObject:_recentConvos forKey:@"recentConvos"];
    [coder encodeObject:_recentPosts forKey:@"recentPosts"];
}

@end
