#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKUser - Reddit user model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKUser : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *fullName;
@property (nonatomic, copy) NSString *profileURL;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, assign) NSInteger commentKarma;
@property (nonatomic, assign) NSInteger linkKarma;
@property (nonatomic, assign) NSInteger awarderKarma;
@property (nonatomic, assign) NSInteger awardeeKarma;
@property (nonatomic, assign) NSInteger inboxCount;
@property (nonatomic, assign) NSInteger totalCoins;
@property (nonatomic, assign) NSInteger totalCreddits;
@property (nonatomic, assign) BOOL hasVerifiedEmailAddress;
@property (nonatomic, assign) BOOL hasMail;
@property (nonatomic, assign) BOOL hasModeratorMail;
@property (nonatomic, assign) BOOL isFetchingSavedItemsDatabase;
@property (nonatomic, strong) NSArray *moderatedSubreddits;
@property (nonatomic, strong) NSArray *multireddits;
@property (nonatomic, strong) NSArray *subscribedSubreddits;
@property (nonatomic, strong) NSArray *friends;
@property (nonatomic, strong) NSArray *blockedUsers;
@property (nonatomic, strong) NSArray *filteredSubreddits;
@property (nonatomic, strong) NSArray *messageThreads;
@property (nonatomic, strong) id modmail;
@property (nonatomic, strong) NSArray *savedItems;
@property (nonatomic, strong) NSArray *locallyFilteredSubreddits;
@property (nonatomic, strong) NSArray *accessibleScopes;
@property (nonatomic, assign) BOOL isGold;
@property (nonatomic, assign) BOOL isFriend;
@property (nonatomic, assign) BOOL isMod;
@property (nonatomic, assign) BOOL isFollowing;
@property (nonatomic, assign) BOOL isOver18;
@property (nonatomic, assign) BOOL noProfanity;

@end
