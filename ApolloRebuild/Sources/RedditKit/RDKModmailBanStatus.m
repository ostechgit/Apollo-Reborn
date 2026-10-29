#import "RDKModmailBanStatus.h"

// RDKModmailBanStatus - Reddit modmail ban status model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: endDate (NSDate *)
//   +0x10: isBanned (BOOL)
//   +0x18: isPermanent (BOOL)
//   +0x20: reason (NSString *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - initWithCoder:
//   - encodeWithCoder:
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - endDateJSONTransformer (Mantle)
//   - endDate, - setEndDate:
//   - isBanned, - setIsBanned:
//   - isPermanent, - setIsPermanent:
//   - reason, - setReason:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKModmailBanStatus

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"endDate": @"end_date",
        @"isBanned": @"is_banned",
        @"isPermanent": @"is_permanent",
        @"reason": @"reason",
    };
}

+ (NSValueTransformer *)endDateJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(NSNumber *value) {
        return [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];} reverseBlock:^id(NSDate *value) {
        return @([value timeIntervalSince1970]);
    }];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _endDate = [coder decodeObjectForKey:@"endDate"];
        _isBanned = [coder decodeBoolForKey:@"isBanned"];
        _isPermanent = [coder decodeBoolForKey:@"isPermanent"];
        _reason = [coder decodeObjectForKey:@"reason"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_endDate forKey:@"endDate"];
    [coder encodeBool:_isBanned forKey:@"isBanned"];
    [coder encodeBool:_isPermanent forKey:@"isPermanent"];
    [coder encodeObject:_reason forKey:@"reason"];
}

@end
