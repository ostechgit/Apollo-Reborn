#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKMedia - Reddit media model (video)
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKMedia : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, strong) id video;

@end
