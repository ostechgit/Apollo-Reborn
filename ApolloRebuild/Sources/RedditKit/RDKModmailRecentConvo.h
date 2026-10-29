#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKModmailRecentConvo - Reddit modmail recent conversation model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKModmailRecentConvo : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *permalink;
@property (nonatomic, copy) NSString *subject;

@end
