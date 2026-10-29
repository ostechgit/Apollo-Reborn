#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKModmailBanStatus - Reddit modmail ban status model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKModmailBanStatus : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, strong) NSDate *endDate;
@property (nonatomic, assign) BOOL isBanned;
@property (nonatomic, assign) BOOL isPermanent;
@property (nonatomic, copy) NSString *reason;

@end
