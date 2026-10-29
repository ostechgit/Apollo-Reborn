#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKVideo - Reddit video model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKVideo : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *URL;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, copy) NSString *fallbackURL;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) BOOL isGIF;
@property (nonatomic, copy) NSString *smallerURL;
@property (nonatomic, assign) NSInteger width;

@end
