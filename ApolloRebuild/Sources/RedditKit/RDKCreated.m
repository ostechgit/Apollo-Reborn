#import "RDKCreated.h"

// RDKCreated - a thing with a creation date
// Reconstructed from apollo-base 1.15.11 binary analysis.

@implementation RDKCreated

+ (NSDictionary<NSString *, id> *)JSONKeyPathsByPropertyKey {
    return [[super JSONKeyPathsByPropertyKey] mtl_dictionaryByAddingEntriesFromDictionary:@{
        @"createdUTC": @"data.created_utc",
    }];
}

+ (NSValueTransformer *)createdUTCJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSNumber *value, BOOL *success, NSError **error) {
        return [value isKindOfClass:[NSNumber class]] ? [NSDate dateWithTimeIntervalSince1970:value.doubleValue] : nil;
    } reverseBlock:^id(NSDate *value, BOOL *success, NSError **error) {
        return value ? @(value.timeIntervalSince1970) : nil;
    }];
}

@end
