#import "RDKMessage.h"

// RDKMessage - Reddit message model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: author (NSString *)
//   +0x10: messageBody (NSString *)
//   +0x18: messageBodyHTML (NSString *)
//   +0x20: distinguished (NSString *)
//   +0x28: recipient (NSString *)
//   +0x30: subject (NSString *)
//   +0x38: replies (NSArray *)
//   +0x40: type (NSString *)
//   +0x48: firstMessage (id)
//   +0x50: subreddit (NSString *)
//   +0x58: firstMessageFullName (NSString *)
//   +0x60: isUnread (BOOL)
//
// Methods recovered:
//   - supportsSecureCoding
//   - modelVersion
//   - allowedSecureCodingClassesByPropertyKey
//   + classForParsingJSONDictionary: (Mantle)
//   - contentType (computed)
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - description
//   - typeJSONTransformer (Mantle)
//   - voteStatusJSONTransformer (Mantle)
//   - repliesJSONTransformer (Mantle)
//   - urlWithContext:
//   - isUnread, - setUnread:
//   - author
//   - messageBody
//   - messageBodyHTML
//   - distinguished, - setDistinguished:
//   - recipient
//   - subject
//   - replies
//   - type
//   - firstMessage
//   - subreddit, - setSubreddit:
//   - firstMessageFullName
//   - isCommentReply (computed)
//   - .cxx_destruct (ARC cleanup)

@implementation RDKMessage

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSUInteger)modelVersion {
    return 1;
}

+ (Class)classForParsingJSONDictionary:(NSDictionary *)dict {
    NSString *type = dict[@"data"][@"type"];
    if ([type isEqualToString:@"comment_reply"]) {
        return NSClassFromString(@"RDKCommentReplyMessage");
    }
    return [RDKMessage class];
}

- (NSString *)contentType {
    if (self.isCommentReply) {
        return @"comment_reply";
    }
    return @"message";
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"author": @"data.author",
        @"messageBody": @"data.body",
        @"messageBodyHTML": @"data.body_html",
        @"distinguished": @"data.distinguished",
        @"recipient": @"data.recipient",
        @"subject": @"data.subject",
        @"replies": @"data.replies",
        @"type": @"data.type",
        @"firstMessage": @"data.first_message",
        @"subreddit": @"data.subreddit",
        @"firstMessageFullName": @"data.first_message_fullname",
        @"isUnread": @"data.unread",
    };
}

+ (NSValueTransformer *)typeJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)voteStatusJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)repliesJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

- (NSString *)urlWithContext:(NSString *)context {
    if (!_firstMessageFullName) {
        return nil;
    }
    return [NSString stringWithFormat:@"https://www.reddit.com%@", _firstMessageFullName];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<RDKMessage: %@ from %@>", self.subject, self.author];
}

- (BOOL)isCommentReply {
    return [_type isEqualToString:@"comment_reply"];
}

@end
