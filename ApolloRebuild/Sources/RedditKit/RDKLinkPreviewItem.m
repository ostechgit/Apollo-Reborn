#import "RDKLinkPreviewItem.h"

// RDKLinkPreviewItem - Reddit link preview item model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: URL (NSString *)
//   +0x10: width (NSInteger)
//   +0x18: height (NSInteger)
//
// Methods recovered:
//   - supportsSecureCoding
//   - modelVersion
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - URLJSONTransformer (Mantle)
//   - URL, - setURL:
//   - width, - setWidth:
//   - height, - setHeight:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKLinkPreviewItem

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSUInteger)modelVersion {
    return 1;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"URL": @"url",
        @"width": @"width",
        @"height": @"height",
    };
}

+ (NSValueTransformer *)URLJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

@end
