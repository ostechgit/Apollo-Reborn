#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKRPANVideo - Reddit RPAN video model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKRPANVideo : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *streamURL;
@property (nonatomic, copy) NSString *thumbnailURL;

@end
