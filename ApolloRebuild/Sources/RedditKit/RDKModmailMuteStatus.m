#import "RDKModmailMuteStatus.h"

// RDKModmailMuteStatus - Reddit modmail mute status model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: endDate (NSDate *)
//   +0x10: isMuted (BOOL)
//   +0x18: reason (NSString *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - initWithCoder:
//   - encodeWithCoder:
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - endDateJSONTransformer (Mantle)
//   - endDate, - setEndDate:
//   - isMuted, - setIsMuted:
//   - reason, - setReason:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKModmailMuteStatus

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"endDate": @"end_date",
        @"isMuted": @"is_muted",
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
        _isMuted = [coder decodeBoolForKey:@"isMuted"];
        _reason = [coder decodeObjectForKey:@"reason"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_endDate forKey:@"endDate"];
    [coder encodeBool:_isMuted forKey:@"isMuted"];
    [coder encodeObject:_reason forKey:@"reason"];
}

@end
