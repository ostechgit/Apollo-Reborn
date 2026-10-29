#import "RDKModmailRecentComment.h"

// RDKModmailRecentComment - Reddit modmail recent comment model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: date (NSDate *)
//   +0x10: comment (NSString *)
//   +0x18: permalink (NSString *)
//   +0x20: title (NSString *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - initWithCoder:
//   - encodeWithCoder:
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - dateJSONTransformer (Mantle)
//   - permalinkJSONTransformer (Mantle)
//   - date, - setDate:
//   - comment, - setComment:
//   - permalink, - setPermalink:
//   - title, - setTitle:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKModmailRecentComment

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"date": @"created_utc",
        @"comment": @"body",
        @"permalink": @"permalink",
        @"title": @"link_title",
    };
}

+ (NSValueTransformer *)dateJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(NSNumber *value) {
        return [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];} reverseBlock:^id(NSDate *value) {
        return @([value timeIntervalSince1970]);
    }];
}

+ (NSValueTransformer *)permalinkJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _date = [coder decodeObjectForKey:@"date"];
        _comment = [coder decodeObjectForKey:@"comment"];
        _permalink = [coder decodeObjectForKey:@"permalink"];
        _title = [coder decodeObjectForKey:@"title"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_date forKey:@"date"];
    [coder encodeObject:_comment forKey:@"comment"];
    [coder encodeObject:_permalink forKey:@"permalink"];
    [coder encodeObject:_title forKey:@"title"];
}

@end
