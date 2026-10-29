#import "RDKGallery.h"

// RDKGallery - Reddit gallery model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: items (NSArray *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - initWithMediaMetadata:galleryData: (build gallery from metadata)
//   - initWithCoder:
//   - encodeWithCoder:
//   - items, - setItems:
//   - .cxx_destruct (ARC cleanup)
//
// This class builds a gallery from Reddit's media metadata and gallery data.
// It iterates through the gallery data, looks up each item's media metadata,
// checks if it's valid, and creates RDKGalleryItem objects.

@implementation RDKGallery {
    NSArray *_items;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithMediaMetadata:(NSDictionary *)mediaMetadata galleryData:(NSArray *)galleryData {
    self = [super init];
    if (self) {
        NSMutableArray *items = [NSMutableArray array];
        
        for (NSDictionary *galleryItem in galleryData) {
            NSString *mediaId = galleryItem[@"media_id"];
            NSDictionary *mediaInfo = mediaMetadata[mediaId];
            
            if (mediaInfo && [mediaInfo[@"status"] isEqualToString:@"valid"]) {
                // Create RDKGalleryItem from media metadata and gallery data
                // (RDKGalleryItem class would be defined separately)
                [items addObject:@{
                    @"media_id": mediaId,
                    @"media": mediaInfo,
                    @"gallery_data": galleryItem,
                }];
            }
        }
        
        _items = [items copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _items = [coder decodeObjectForKey:@"items"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_items forKey:@"items"];
}

- (NSArray *)items {
    return _items;
}

- (void)setItems:(NSArray *)items {
    _items = [items copy];
}

@end
