#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKModmailConversation - Reddit modmail conversation model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKModmailConversation : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) id conversationInfo;
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) NSArray *modActions;
@property (nonatomic, strong) id user;
@property (nonatomic, strong) id firstOptionConversationInfo;
@property (nonatomic, strong) id secondOptionConversationInfo;

@end
