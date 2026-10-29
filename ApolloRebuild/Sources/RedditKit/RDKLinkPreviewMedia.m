#import "RDKLinkPreviewMedia.h"

// RDKLinkPreviewMedia - Reddit link preview media model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: images (NSArray *)
//   +0x10: sourceImage (id)
//   +0x18: MP4s (NSArray *)
//   +0x20: sourceMP4 (id)
//   +0x28: GIFs (NSArray *)
//   +0x30: sourceGIF (id)
//
// Methods recovered:
//   - supportsSecureCoding
//   - modelVersion
//   - allowedSecureCodingClassesByPropertyKey
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - imagesJSONTransformer (Mantle)
//   - sourceImageJSONTransformer (Mantle)
//   - MP4sJSONTransformer (Mantle)
//   - sourceMP4JSONTransformer (Mantle)
//   - GIFsJSONTransformer (Mantle)
//   - sourceGIFJSONTransformer (Mantle)
//   - images, - setImages:
//   - sourceImage, - setSourceImage:
//   - MP4s, - setMP4s:
//   - sourceMP4, - setSourceMP4:
//   - GIFs, - setGIFs:
//   - sourceGIF, - setSourceGIF:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKLinkPreviewMedia

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSUInteger)modelVersion {
    return 1;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"images": @"images",
        @"sourceImage": @"source",
        @"MP4s": @"mp4s",
        @"sourceMP4": @"source_mp4",
        @"GIFs": @"gifs",
        @"sourceGIF": @"source_gif",
    };
}

+ (NSValueTransformer *)imagesJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)sourceImageJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)MP4sJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)sourceMP4JSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)GIFsJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)sourceGIFJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

@end
