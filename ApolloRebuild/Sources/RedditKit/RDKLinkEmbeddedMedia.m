#import "RDKLinkEmbeddedMedia.h"

// RDKLinkEmbeddedMedia - Reddit link embedded media model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: type (NSString *)
//   +0x10: authorName (NSString *)
//   +0x18: authorURL (NSString *)
//   +0x20: providerURL (NSString *)
//   +0x28: providerDescription (NSString *)
//   +0x30: providerTitle (NSString *)
//   +0x38: width (NSInteger)
//   +0x40: height (NSInteger)
//   +0x48: thumbnailWidth (NSInteger)
//   +0x50: thumbnailHeight (NSInteger)
//   +0x58: thumbnailURL (NSString *)
//
// Methods recovered:
//   - initWithCoder:
//   - encodeWithCoder:
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - description
//   - type, - setType:
//   - authorName, - setAuthorName:
//   - authorURL, - setAuthorURL:
//   - providerURL, - setProviderURL:
//   - providerDescription, - setProviderDescription:
//   - providerTitle, - setProviderTitle:
//   - width, - setWidth:
//   - height, - setHeight:
//   - thumbnailWidth, - setThumbnailWidth:
//   - thumbnailHeight, - setThumbnailHeight:
//   - thumbnailURL, - setThumbnailURL:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKLinkEmbeddedMedia

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"type": @"type",
        @"authorName": @"author_name",
        @"authorURL": @"author_url",
        @"providerURL": @"provider_url",
        @"providerDescription": @"provider_description",
        @"providerTitle": @"provider_title",
        @"width": @"width",
        @"height": @"height",
        @"thumbnailWidth": @"thumbnail_width",
        @"thumbnailHeight": @"thumbnail_height",
        @"thumbnailURL": @"thumbnail_url",
    };
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<RDKLinkEmbeddedMedia: %@>", self.type];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _type = [coder decodeObjectForKey:@"type"];
        _authorName = [coder decodeObjectForKey:@"authorName"];
        _authorURL = [coder decodeObjectForKey:@"authorURL"];
        _providerURL = [coder decodeObjectForKey:@"providerURL"];
        _providerDescription = [coder decodeObjectForKey:@"providerDescription"];
        _providerTitle = [coder decodeObjectForKey:@"providerTitle"];
        _width = [coder decodeIntegerForKey:@"width"];
        _height = [coder decodeIntegerForKey:@"height"];
        _thumbnailWidth = [coder decodeIntegerForKey:@"thumbnailWidth"];
        _thumbnailHeight = [coder decodeIntegerForKey:@"thumbnailHeight"];
        _thumbnailURL = [coder decodeObjectForKey:@"thumbnailURL"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_type forKey:@"type"];
    [coder encodeObject:_authorName forKey:@"authorName"];
    [coder encodeObject:_authorURL forKey:@"authorURL"];
    [coder encodeObject:_providerURL forKey:@"providerURL"];
    [coder encodeObject:_providerDescription forKey:@"providerDescription"];
    [coder encodeObject:_providerTitle forKey:@"providerTitle"];
    [coder encodeInteger:_width forKey:@"width"];
    [coder encodeInteger:_height forKey:@"height"];
    [coder encodeInteger:_thumbnailWidth forKey:@"thumbnailWidth"];
    [coder encodeInteger:_thumbnailHeight forKey:@"thumbnailHeight"];
    [coder encodeObject:_thumbnailURL forKey:@"thumbnailURL"];
}

@end
