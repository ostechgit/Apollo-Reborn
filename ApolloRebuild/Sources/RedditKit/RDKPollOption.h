#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKPollOption - Reddit poll option model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKPollOption : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) NSInteger voteCount;

@end
