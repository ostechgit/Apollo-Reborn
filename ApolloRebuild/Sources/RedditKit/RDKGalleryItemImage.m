#import "RDKGalleryItemImage.h"

// RDKGalleryItemImage - Reddit gallery image model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: width (NSInteger)
//   +0x10: height (NSInteger)
//   +0x18: url (NSString *)
//   +0x20: mp4URL (NSString *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - modelVersion
//   - JSONKeyPathsByPropertyKey (Mantle: height -> y, mp4URL -> mp4, url -> u, width -> x)
//   - urlJSONTransformer (Mantle)
//   - mp4URLJSONTransformer (Mantle)
//   - width, - setWidth:
//   - height, - setHeight:
//   - url, - setUrl:
//   - mp4URL, - setMp4URL:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKGalleryItemImage

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSUInteger)modelVersion {
    return 1;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"height": @"y",
        @"mp4URL": @"mp4",
        @"url": @"u",
        @"width": @"x",
    };
}

+ (NSValueTransformer *)urlJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)mp4URLJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

@end
