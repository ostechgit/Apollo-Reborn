#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKModmailMuteStatus - Reddit modmail mute status model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKModmailMuteStatus : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, strong) NSDate *endDate;
@property (nonatomic, assign) BOOL isMuted;
@property (nonatomic, copy) NSString *reason;

@end
