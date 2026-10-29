#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKFlair - Reddit flair model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKFlair : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *flairType;
@property (nonatomic, copy) NSString *imageURL;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *emojiLabel;

@end
