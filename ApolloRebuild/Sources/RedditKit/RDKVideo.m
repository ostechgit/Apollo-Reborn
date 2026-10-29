#import "RDKVideo.h"

// RDKVideo - Reddit video model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: URL (NSString *)
//   +0x10: duration (NSTimeInterval)
//   +0x18: fallbackURL (NSString *)
//   +0x20: height (NSInteger)
//   +0x28: isGIF (BOOL)
//   +0x30: smallerURL (NSString *)
//   +0x38: width (NSInteger)
//
// Methods recovered:
//   - supportsSecureCoding
//   - modelVersion
//   - JSONKeyPathsByPropertyKey (Mantle: URL -> hls_url, duration -> duration, fallbackURL -> fallback_url, height -> height, isGIF -> is_gif, smallerURL -> scrubber_media_url, width -> width)
//   - URLJSONTransformer (Mantle)
//   - smallerURLJSONTransformer (Mantle)
//   - fallbackURLJSONTransformer (Mantle)
//   - duration, - setDuration:
//   - URL, - setURL:
//   - smallerURL, - setSmallerURL:
//   - isGIF, - setIsGIF:
//   - width, - setWidth:
//   - height, - setHeight:
//   - fallbackURL, - setFallbackURL:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKVideo

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSUInteger)modelVersion {
    return 1;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"URL": @"hls_url",
        @"duration": @"duration",
        @"fallbackURL": @"fallback_url",
        @"height": @"height",
        @"isGIF": @"is_gif",
        @"smallerURL": @"scrubber_media_url",
        @"width": @"width",
    };
}

+ (NSValueTransformer *)URLJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)smallerURLJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)fallbackURLJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

@end
