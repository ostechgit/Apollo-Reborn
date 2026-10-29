#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKModmailConversationInfo - Reddit modmail conversation info model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKModmailConversationInfo : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, strong) NSArray *authors;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) BOOL isAutomoderator;
@property (nonatomic, assign) BOOL isHighlighted;
@property (nonatomic, assign) BOOL isInternal;
@property (nonatomic, assign) BOOL isRepliable;
@property (nonatomic, strong) NSDate *lastModeratorUpdate;
@property (nonatomic, strong) NSDate *lastUnread;
@property (nonatomic, strong) NSDate *lastUpdated;
@property (nonatomic, strong) NSDate *lastUserUpdate;
@property (nonatomic, assign) NSInteger totalMessages;
@property (nonatomic, copy) NSString *owner;
@property (nonatomic, strong) id participant;
@property (nonatomic, copy) NSString *state;
@property (nonatomic, copy) NSString *subject;
@property (nonatomic, strong) NSArray *objIDs;

@end
