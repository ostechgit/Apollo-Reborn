#import "RDKFlair.h"

// RDKFlair - Reddit flair model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: flairType (NSString *)
//   +0x10: imageURL (NSString *)
//   +0x18: text (NSString *)
//   +0x20: emojiLabel (NSString *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - modelVersion
//   - initWithRawText:
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - imageURLJSONTransformer (Mantle)
//   - textJSONTransformer (Mantle)
//   - emojiLabelJSONTransformer (Mantle)
//   - flairType, - setFlairType:
//   - imageURL, - setImageURL:
//   - text, - setText:
//   - emojiLabel, - setEmojiLabel:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKFlair

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSUInteger)modelVersion {
    return 1;
}

- (instancetype)initWithRawText:(NSString *)text {
    self = [super init];
    if (self) {
        _text = [text copy];
    }
    return self;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"flairType": @"flair_type",
        @"imageURL": @"icon_url",
        @"text": @"text",
        @"emojiLabel": @"emoji",
    };
}

+ (NSValueTransformer *)imageURLJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)textJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)emojiLabelJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

@end
