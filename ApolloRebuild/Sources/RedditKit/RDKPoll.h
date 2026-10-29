#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKPoll - Reddit poll model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKPoll : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, strong) NSArray *options;
@property (nonatomic, assign) NSInteger totalVoteCount;
@property (nonatomic, copy) NSString *userSelectionIdentifier;
@property (nonatomic, strong) NSDate *votingEnd;

@end
