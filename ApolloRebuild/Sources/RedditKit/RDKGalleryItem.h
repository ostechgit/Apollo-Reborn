#import <Foundation/Foundation.h>

// RDKGalleryItem - Reddit gallery item model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKGalleryItem : NSObject <NSCoding>

- (instancetype)initWithMediaMetadata:(NSDictionary *)mediaMetadata galleryData:(NSDictionary *)galleryData;
- (instancetype)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder *)coder;

@property (nonatomic, copy) NSString *caption;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *mediaIdentifier;
@property (nonatomic, copy) NSString *outboundURL;
@property (nonatomic, strong) NSArray *previewImages;
@property (nonatomic, strong) id image;

@end
