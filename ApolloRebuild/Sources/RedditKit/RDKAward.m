#import "RDKAward.h"

// RDKAward - Reddit award model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: awardType (NSString *)
//   +0x10: awardSubType (NSString *)
//   +0x18: coinPrice (NSInteger)
//   +0x20: count (NSInteger)
//   +0x28: awardDescription (NSString *)
//   +0x30: identifier (NSString *)
//   +0x38: isEnabled (BOOL)
//   +0x40: isNew (BOOL)
//   +0x48: name (NSString *)
//   +0x50: subredditCoinAward (BOOL)
//   +0x58: subredditFullname (NSString *)
//   +0x60: resizedIcons (NSArray *)
//   +0x68: largeIconURL (NSString *)
//   +0x70: largeIconWidth (NSInteger)
//
// Methods recovered:
//   - supportsSecureCoding
//   - modelVersion
//   - allowedSecureCodingClassesByPropertyKey
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - largeIconURLJSONTransformer (Mantle)
//   - awardTypeJSONTransformer (Mantle)
//   - awardSubTypeJSONTransformer (Mantle)
//   - resizedIconsJSONTransformer (Mantle)
//   - resizedIconURLClosestToWidth:
//   - awardType, - setAwardType:
//   - awardSubType, - setAwardSubType:
//   - coinPrice, - setCoinPrice:
//   - count, - setCount:
//   - awardDescription, - setAwardDescription:
//   - identifier, - setIdentifier:
//   - isEnabled, - setIsEnabled:
//   - isNew, - setIsNew:
//   - name, - setName:
//   - subredditCoinAward, - setSubredditCoinAward:
//   - subredditFullname, - setSubredditFullname:
//   - resizedIcons, - setResizedIcons:
//   - largeIconURL, - setLargeIconURL:
//   - largeIconWidth, - setLargeIconWidth:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKAward

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSUInteger)modelVersion {
    return 1;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"awardType": @"award_type",
        @"awardSubType": @"award_sub_type",
        @"coinPrice": @"coin_price",
        @"count": @"count",
        @"awardDescription": @"description",
        @"identifier": @"id",
        @"isEnabled": @"is_enabled",
        @"isNew": @"is_new",
        @"name": @"name",
        @"subredditCoinAward": @"subreddit_coin_award",
        @"subredditFullname": @"subreddit_fullname",
        @"resizedIcons": @"resized_icons",
        @"largeIconURL": @"large_icon_url",
        @"largeIconWidth": @"large_icon_width",
    };
}

+ (NSValueTransformer *)largeIconURLJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)awardTypeJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)awardSubTypeJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)resizedIconsJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

- (NSString *)resizedIconURLClosestToWidth:(NSInteger)width {
    if (!_resizedIcons) {
        return self.largeIconURL;
    }
    
    NSString *bestURL = nil;
    NSInteger bestWidth = 0;
    
    for (id icon in _resizedIcons) {
        if ([icon isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = icon;
            NSString *url = dict[@"url"];
            NSNumber *w = dict[@"width"];
            if (url && w && [w integerValue] <= width && [w integerValue] > bestWidth) {
                bestURL = url;
                bestWidth = [w integerValue];
            }
        }
    }
    
    return bestURL ?: self.largeIconURL;
}

@end
