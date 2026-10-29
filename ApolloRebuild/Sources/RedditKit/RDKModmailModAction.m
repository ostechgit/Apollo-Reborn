#import "RDKModmailModAction.h"

// RDKModmailModAction - Reddit modmail mod action model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: actionType (NSString *)
//   +0x10: author (id)
//   +0x18: date (NSDate *)
//   +0x20: identifier (NSString *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - JSONKeyPathsByPropertyKey (Mantle: actionType -> actionTypeId, author -> author, date -> date, identifier -> id)
//   - actionTypeJSONTransformer (Mantle)
//   - dateJSONTransformer (Mantle)
//   - authorJSONTransformer (Mantle)
//   - actionType, - setActionType:
//   - author, - setAuthor:
//   - date, - setDate:
//   - identifier, - setIdentifier:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKModmailModAction

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"actionType": @"actionTypeId",
        @"author": @"author",
        @"date": @"date",
        @"identifier": @"id",
    };
}

+ (NSValueTransformer *)actionTypeJSONTransformer {
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

+ (NSValueTransformer *)authorJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

@end
