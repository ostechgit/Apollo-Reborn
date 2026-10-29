#import "RDKModmailMessage.h"

// RDKModmailMessage - Reddit modmail message model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: author (id)
//   +0x10: bodyHTML (NSString *)
//   +0x18: bodyMarkdown (NSString *)
//   +0x20: date (NSDate *)
//   +0x28: identifier (NSString *)
//   +0x30: isInternal (BOOL)
//   +0x38: conversationInfo (id)
//
// Methods recovered:
//   - supportsSecureCoding
//   - modelVersion
//   - JSONKeyPathsByPropertyKey (Mantle: author -> author, bodyHTML -> body, bodyMarkdown -> bodyMarkdown, date -> date, identifier -> id, isInternal -> isInternal)
//   - authorJSONTransformer (Mantle)
//   - dateJSONTransformer (Mantle)
//   - author, - setAuthor:
//   - bodyHTML, - setBodyHTML:
//   - bodyMarkdown, - setBodyMarkdown:
//   - date, - setDate:
//   - identifier, - setIdentifier:
//   - isInternal, - setIsInternal:
//   - conversationInfo, - setConversationInfo:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKModmailMessage

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSUInteger)modelVersion {
    return 1;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"author": @"author",
        @"bodyHTML": @"body",
        @"bodyMarkdown": @"bodyMarkdown",
        @"date": @"date",
        @"identifier": @"id",
        @"isInternal": @"isInternal",
    };
}

+ (NSValueTransformer *)authorJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)dateJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(NSNumber *value) {
        return [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];} reverseBlock:^id(NSDate *value) {
        return @([value timeIntervalSince1970]);
    }];
}

@end
