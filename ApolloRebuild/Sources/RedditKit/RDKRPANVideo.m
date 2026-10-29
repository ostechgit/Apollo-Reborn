#import "RDKRPANVideo.h"

// RDKRPANVideo - Reddit RPAN video model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: streamURL (NSString *)
//   +0x10: thumbnailURL (NSString *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - modelVersion
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - streamURLJSONTransformer (Mantle)
//   - thumbnailURLJSONTransformer (Mantle)
//   - streamURL, - setStreamURL:
//   - thumbnailURL, - setThumbnailURL:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKRPANVideo

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSUInteger)modelVersion {
    return 1;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"streamURL": @"stream_url",
        @"thumbnailURL": @"thumbnail_url",
    };
}

+ (NSValueTransformer *)streamURLJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)thumbnailURLJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

@end
