#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKMessage - Reddit message model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKMessage : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *messageBody;
@property (nonatomic, copy) NSString *messageBodyHTML;
@property (nonatomic, copy) NSString *distinguished;
@property (nonatomic, copy) NSString *recipient;
@property (nonatomic, copy) NSString *subject;
@property (nonatomic, strong) NSArray *replies;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, strong) id firstMessage;
@property (nonatomic, copy) NSString *subreddit;
@property (nonatomic, copy) NSString *firstMessageFullName;
@property (nonatomic, assign) BOOL isUnread;

@end
