#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKModmailRecentComment - Reddit modmail recent comment model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKModmailRecentComment : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSString *comment;
@property (nonatomic, copy) NSString *permalink;
@property (nonatomic, copy) NSString *title;

@end
