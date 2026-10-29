#import "RDKUser.h"

// RDKUser - Reddit user model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: fullName (NSString *)
//   +0x10: profileURL (NSString *)
//   +0x18: username (NSString *)
//   +0x20: commentKarma (NSInteger)
//   +0x28: linkKarma (NSInteger)
//   +0x30: awarderKarma (NSInteger)
//   +0x38: awardeeKarma (NSInteger)
//   +0x40: inboxCount (NSInteger)
//   +0x48: totalCoins (NSInteger)
//   +0x50: totalCreddits (NSInteger)
//   +0x58: hasVerifiedEmailAddress (BOOL)
//   +0x60: hasMail (BOOL)
//   +0x68: hasModeratorMail (BOOL)
//   +0x70: isFetchingSavedItemsDatabase (BOOL)
//   +0x78: moderatedSubreddits (NSArray *)
//   +0x80: multireddits (NSArray *)
//   +0x88: subscribedSubreddits (NSArray *)
//   +0x90: friends (NSArray *)
//   +0x98: blockedUsers (NSArray *)
//   +0xa0: filteredSubreddits (NSArray *)
//   +0xa8: messageThreads (NSArray *)
//   +0xb0: modmail (id)
//   +0xb8: savedItems (NSArray *)
//   +0xc0: locallyFilteredSubreddits (NSArray *)
//   +0xc8: accessibleScopes (NSArray *)
//   +0xd0: isGold (BOOL)
//   +0xd8: isFriend (BOOL)
//   +0xe0: isMod (BOOL)
//   +0xe8: isFollowing (BOOL)
//   +0xf0: isOver18 (BOOL)
//   +0xf8: noProfanity (BOOL)
//
// Methods recovered:
//   - supportsSecureCoding
//   - setSavedItems:
//   - allowedSecureCodingClassesByPropertyKey
//   - encodingBehaviorsByPropertyKey
//   - decodeMessageThreadsWithCoder:modelVersion:
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - description
//   - JSONTransformerForKey: (Mantle)
//   - fullName
//   - profileURL
//   - username, - setUsername:
//   - commentKarma, - setCommentKarma:
//   - linkKarma, - setLinkKarma:
//   - awarderKarma, - setAwarderKarma:
//   - awardeeKarma, - setAwardeeKarma:
//   - inboxCount, - setInboxCount:
//   - totalCoins, - setTotalCoins:
//   - totalCreddits, - setTotalCreddits:
//   - hasVerifiedEmailAddress, - setHasVerifiedEmailAddress:
//   - hasMail, - setHasMail:
//   - hasModeratorMail, - setHasModeratorMail:
//   - isFetchingSavedItemsDatabase, - setIsFetchingSavedItemsDatabase:
//   - moderatedSubreddits, - setModeratedSubreddits:
//   - multireddits, - setMultireddits:
//   - subscribedSubreddits, - setSubscribedSubreddits:
//   - friends, - setFriends:
//   - blockedUsers, - setBlockedUsers:
//   - filteredSubreddits, - setFilteredSubreddits:
//   - messageThreads, - setMessageThreads:
//   - modmail, - setModmail:
//   - savedItems
//   - locallyFilteredSubreddits, - setLocallyFilteredSubreddits:
//   - accessibleScopes, - setAccessibleScopes:
//   - isGold, - setGold:
//   - isFriend, - setFriend:
//   - isMod, - setMod:
//   - isFollowing, - setIsFollowing:
//   - isOver18, - setOver18:
//   - noProfanity, - setNoProfanity:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKUser

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"fullName": @"data.name",
        @"profileURL": @"data.url",
        @"username": @"data.name",
        @"commentKarma": @"data.comment_karma",
        @"linkKarma": @"data.link_karma",
        @"awarderKarma": @"data.awarder_karma",
        @"awardeeKarma": @"data.awardee_karma",
        @"inboxCount": @"data.inbox_count",
        @"totalCoins": @"data.total_coin",
        @"totalCreddits": @"data.total_creddits",
        @"hasVerifiedEmailAddress": @"data.has_verified_email",
        @"hasMail": @"data.has_mail",
        @"hasModeratorMail": @"data.has_modmail",
        @"isFetchingSavedItemsDatabase": @"data.is_fetching_saved_items_database",
        @"moderatedSubreddits": @"data.moderated_subreddits",
        @"multireddits": @"data.multireddits",
        @"subscribedSubreddits": @"data.subscribed_subreddits",
        @"friends": @"data.friends",
        @"blockedUsers": @"data.blocked_users",
        @"filteredSubreddits": @"data.filtered_subreddits",
        @"messageThreads": @"data.message_threads",
        @"modmail": @"data.modmail",
        @"savedItems": @"data.saved_items",
        @"locallyFilteredSubreddits": @"data.locally_filtered_subreddits",
        @"accessibleScopes": @"data.accessible_scopes",
        @"isGold": @"data.is_gold",
        @"isFriend": @"data.is_friend",
        @"isMod": @"data.is_mod",
        @"isFollowing": @"data.is_following",
        @"isOver18": @"data.is_over_18",
        @"noProfanity": @"data.no_profanity",
    };
}

+ (NSValueTransformer *)JSONTransformerForKey:(NSString *)key {
    if ([key isEqualToString:@"moderatedSubreddits"]) {
        return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
            return value;} reverseBlock:^id(id value) {
            return value;
        }];
    }
    return nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<RDKUser: %@>", self.username];
}

- (NSString *)profileURL {
    return [NSString stringWithFormat:@"https://www.reddit.com/user/%@", self.username];
}

@end
