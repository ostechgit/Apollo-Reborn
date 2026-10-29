#import <Foundation/Foundation.h>

// RDKGallery - Reddit gallery model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKGallery : NSObject <NSCoding>

- (instancetype)initWithMediaMetadata:(NSDictionary *)mediaMetadata galleryData:(NSArray *)galleryData;
- (instancetype)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder *)coder;

@property (nonatomic, strong) NSArray *items;

@end
