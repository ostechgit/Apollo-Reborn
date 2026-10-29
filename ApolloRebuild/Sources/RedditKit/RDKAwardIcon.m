#import "RDKAwardIcon.h"

// RDKAwardIcon - Reddit award icon model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: width (NSInteger)
//   +0x10: height (NSInteger)
//   +0x18: url (NSString *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - modelVersion
//   - JSONKeyPathsByPropertyKey (Mantle: height -> height, url -> url, width -> width)
//   - urlJSONTransformer (Mantle)
//   - width, - setWidth:
//   - height, - setHeight:
//   - url, - setUrl:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKAwardIcon

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSUInteger)modelVersion {
    return 1;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"height": @"height",
        @"url": @"url",
        @"width": @"width",
    };
}

+ (NSValueTransformer *)urlJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

@end
