#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKModmailModAction - Reddit modmail mod action model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKModmailModAction : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *actionType;
@property (nonatomic, strong) id author;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSString *identifier;

@end
