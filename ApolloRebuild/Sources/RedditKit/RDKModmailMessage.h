#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKModmailMessage - Reddit modmail message model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKModmailMessage : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, strong) id author;
@property (nonatomic, copy) NSString *bodyHTML;
@property (nonatomic, copy) NSString *bodyMarkdown;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) BOOL isInternal;
@property (nonatomic, strong) id conversationInfo;

@end
