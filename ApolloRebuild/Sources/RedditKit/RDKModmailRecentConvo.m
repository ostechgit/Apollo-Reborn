#import "RDKModmailRecentConvo.h"

// RDKModmailRecentConvo - Reddit modmail recent conversation model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: date (NSDate *)
//   +0x10: identifier (NSString *)
//   +0x18: permalink (NSString *)
//   +0x20: subject (NSString *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - initWithCoder:
//   - encodeWithCoder:
//   - JSONKeyPathsByPropertyKey (Mantle: date -> date, identifier -> id, permalink -> permalink, subject -> subject)
//   - dateJSONTransformer (Mantle)
//   - permalinkJSONTransformer (Mantle)
//   - date, - setDate:
//   - identifier, - setIdentifier:
//   - permalink, - setPermalink:
//   - subject, - setSubject:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKModmailRecentConvo

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"date": @"date",
        @"identifier": @"id",
        @"permalink": @"permalink",
        @"subject": @"subject",
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
        _identifier = [coder decodeObjectForKey:@"identifier"];
        _permalink = [coder decodeObjectForKey:@"permalink"];
        _subject = [coder decodeObjectForKey:@"subject"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_date forKey:@"date"];
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_permalink forKey:@"permalink"];
    [coder encodeObject:_subject forKey:@"subject"];
}

@end
