#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKAwardIcon - Reddit award icon model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKAwardIcon : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, copy) NSString *url;

@end
