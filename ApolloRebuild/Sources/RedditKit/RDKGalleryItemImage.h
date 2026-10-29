#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKGalleryItemImage - Reddit gallery image model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKGalleryItemImage : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *mp4URL;

@end
