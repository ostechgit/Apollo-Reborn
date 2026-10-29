#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>
#import "RDKThing.h"

// RDKSubreddit - Reddit subreddit model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKSubreddit : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *display_name;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *URL;
@property (nonatomic, copy) NSString *subredditDescription;
@property (nonatomic, copy) NSString *subredditDescriptionHTML;
@property (nonatomic, copy) NSString *publicDescription;
@property (nonatomic, copy) NSString *headerImageURL;
@property (nonatomic, copy) NSString *headerTitle;
@property (nonatomic, copy) NSString *iconURL;
@property (nonatomic, copy) NSString *communityIconURL;
@property (nonatomic, copy) NSString *iconImageURL;
@property (nonatomic, assign) NSInteger totalSubscribers;
@property (nonatomic, assign) NSInteger accountsActive;
@property (nonatomic, assign) BOOL isOver18;
@property (nonatomic, assign) BOOL isContributor;
@property (nonatomic, assign) BOOL isModerator;
@property (nonatomic, assign) BOOL isSubscriber;
@property (nonatomic, assign) BOOL isBanned;
@property (nonatomic, assign) BOOL canCrosspostTo;
@property (nonatomic, copy) NSString *acceptedSubmissionsType;
@property (nonatomic, assign) BOOL allowImagePosts;
@property (nonatomic, assign) BOOL allowVideoGIFPosts;
@property (nonatomic, assign) BOOL allowVideoPosts;
@property (nonatomic, copy) NSString *subredditType;
@property (nonatomic, assign) NSInteger commentSpamFilterStrength;
@property (nonatomic, assign) NSInteger linkSpamFilterStrength;
@property (nonatomic, assign) NSInteger selfPostSpamFilterStrength;
@property (nonatomic, strong) NSArray *rules;
@property (nonatomic, copy) NSString *submitLinkPostLabel;
@property (nonatomic, copy) NSString *submitTextPostLabel;
@property (nonatomic, copy) NSString *submitText;
@property (nonatomic, copy) NSString *submitTextHTML;
@property (nonatomic, assign) BOOL trafficPagePubliclyAccessible;
@property (nonatomic, copy) NSString *oldSiteColorHexcode;
@property (nonatomic, copy) NSString *redesignColorHexcode;
@property (nonatomic, copy) NSString *userFlairID;
@property (nonatomic, assign) BOOL showUserFlair;
@property (nonatomic, assign) BOOL canSetFlair;
@property (nonatomic, assign) BOOL isEnrolledInNewModmail;
@property (nonatomic, copy) NSString *whitelistStatus;
@property (nonatomic, assign) NSInteger commentScoreHiddenDuration;

@end
