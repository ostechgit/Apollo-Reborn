#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKLinkPreviewMedia - Reddit link preview media model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKLinkPreviewMedia : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, strong) NSArray *images;
@property (nonatomic, strong) id sourceImage;
@property (nonatomic, strong) NSArray *MP4s;
@property (nonatomic, strong) id sourceMP4;
@property (nonatomic, strong) NSArray *GIFs;
@property (nonatomic, strong) id sourceGIF;

@end
