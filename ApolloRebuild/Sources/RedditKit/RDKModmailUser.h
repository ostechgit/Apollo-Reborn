#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKModmailUser - Reddit modmail user model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKModmailUser : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, strong) id banStatus;
@property (nonatomic, strong) NSDate *created;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) BOOL isShadowBanned;
@property (nonatomic, assign) BOOL isSuspended;
@property (nonatomic, strong) id muteStatus;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSArray *recentComments;
@property (nonatomic, strong) NSArray *recentConvos;
@property (nonatomic, strong) NSArray *recentPosts;

@end
