#import "RDKGalleryItem.h"

// RDKGalleryItem - Reddit gallery item model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: caption (NSString *)
//   +0x10: identifier (NSString *)
//   +0x18: mediaIdentifier (NSString *)
//   +0x20: outboundURL (NSString *)
//   +0x28: previewImages (NSArray *)
//   +0x30: image (id)
//
// Methods recovered:
//   - supportsSecureCoding
//   - initWithCoder:
//   - encodeWithCoder:
//   - initWithMediaMetadata:galleryData:
//   - caption, - setCaption:
//   - identifier, - setIdentifier:
//   - mediaIdentifier, - setMediaIdentifier:
//   - outboundURL, - setOutboundURL:
//   - previewImages, - setPreviewImages:
//   - image, - setImage:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKGalleryItem {
    NSString *_caption;
    NSString *_identifier;
    NSString *_mediaIdentifier;
    NSString *_outboundURL;
    NSArray *_previewImages;
    id _image;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithMediaMetadata:(NSDictionary *)mediaMetadata galleryData:(NSDictionary *)galleryData {
    self = [super init];
    if (self) {
        _mediaIdentifier = galleryData[@"media_id"];
        _identifier = galleryData[@"id"];
        _caption = galleryData[@"caption"];
        _outboundURL = galleryData[@"outbound_url"];
        _previewImages = galleryData[@"preview_images"];
        
        if (mediaMetadata) {
            NSDictionary *mediaInfo = mediaMetadata[_mediaIdentifier];
            if (mediaInfo) {
                _image = mediaInfo;
            }
        }
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _caption = [coder decodeObjectForKey:@"caption"];
        _identifier = [coder decodeObjectForKey:@"identifier"];
        _mediaIdentifier = [coder decodeObjectForKey:@"mediaIdentifier"];
        _outboundURL = [coder decodeObjectForKey:@"outboundURL"];
        _previewImages = [coder decodeObjectForKey:@"previewImages"];
        _image = [coder decodeObjectForKey:@"image"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_caption forKey:@"caption"];
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_mediaIdentifier forKey:@"mediaIdentifier"];
    [coder encodeObject:_outboundURL forKey:@"outboundURL"];
    [coder encodeObject:_previewImages forKey:@"previewImages"];
    [coder encodeObject:_image forKey:@"image"];
}

@end
