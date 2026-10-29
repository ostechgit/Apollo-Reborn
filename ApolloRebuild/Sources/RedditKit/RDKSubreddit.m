#import "RDKSubreddit.h"

// RDKSubreddit - Reddit subreddit model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: name (NSString *)
//   +0x10: title (NSString *)
//   +0x18: URL (NSString *)
//   +0x20: subredditDescription (NSString *)
//   +0x28: subredditDescriptionHTML (NSString *)
//   +0x30: publicDescription (NSString *)
//   +0x38: headerImageURL (NSString *)
//   +0x40: headerTitle (NSString *)
//   +0x48: iconURL (NSString *)
//   +0x50: communityIconURL (NSString *)
//   +0x58: iconImageURL (NSString *)
//   +0x60: totalSubscribers (NSInteger)
//   +0x68: accountsActive (NSInteger)
//   +0x70: isOver18 (BOOL)
//   +0x78: isContributor (BOOL)
//   +0x80: isModerator (BOOL)
//   +0x88: isSubscriber (BOOL)
//   +0x90: isBanned (BOOL)
//   +0x98: canCrosspostTo (BOOL)
//   +0xa0: acceptedSubmissionsType (NSString *)
//   +0xa8: allowImagePosts (BOOL)
//   +0xb0: allowVideoGIFPosts (BOOL)
//   +0xb8: allowVideoPosts (BOOL)
//   +0xc0: subredditType (NSString *)
//   +0xc8: commentSpamFilterStrength (NSInteger)
//   +0xd0: linkSpamFilterStrength (NSInteger)
//   +0xd8: selfPostSpamFilterStrength (NSInteger)
//   +0xe0: rules (NSArray *)
//   +0xe8: submitLinkPostLabel (NSString *)
//   +0xf0: submitTextPostLabel (NSString *)
//   +0xf8: submitText (NSString *)
//   +0x100: submitTextHTML (NSString *)
//   +0x108: trafficPagePubliclyAccessible (BOOL)
//   +0x110: oldSiteColorHexcode (NSString *)
//   +0x118: redesignColorHexcode (NSString *)
//   +0x120: userFlairID (NSString *)
//   +0x128: showUserFlair (BOOL)
//   +0x130: canSetFlair (BOOL)
//   +0x138: isEnrolledInNewModmail (BOOL)
//   +0x140: whitelistStatus (NSString *)
//   +0x148: commentScoreHiddenDuration (NSInteger)
//
// Methods recovered:
//   - supportsSecureCoding
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - description
//   - JSONTransformerForKey: (Mantle)
//   - totalSubscribersJSONTransformer (Mantle)
//   - accountsActiveJSONTransformer (Mantle)
//   - canCrosspostToJSONTransformer (Mantle)
//   - headerImageURLJSONTransformer (Mantle)
//   - communityIconURLJSONTransformer (Mantle)
//   - iconImageURLJSONTransformer (Mantle)
//   - acceptedSubmissionsTypeJSONTransformer (Mantle)
//   - subredditTypeJSONTransformer (Mantle)
//   - showUserFlairJSONTransformer (Mantle)
//   - commentSpamFilterStrengthJSONTransformer (Mantle)
//   - linkSpamFilterStrengthJSONTransformer (Mantle)
//   - selfPostSpamFilterStrengthJSONTransformer (Mantle)
//   - spamFilterValueTransformer (Mantle)
//   - rulesJSONTransformer (Mantle)
//   - oldSiteColorHexcode
//   - redesignColorHexcode
//   - iconURL
//   - accountsActive
//   - commentScoreHiddenDuration
//   - name
//   - canCrosspostTo, - setCanCrosspostTo:
//   - subredditDescription
//   - subredditDescriptionHTML
//   - isEnrolledInNewModmail, - setIsEnrolledInNewModmail:
//   - whitelistStatus, - setWhitelistStatus:
//   - publicDescription
//   - headerImageURL
//   - headerTitle
//   - setRedesignColorHexcode:
//   - setOldSiteColorHexcode:
//   - userFlairID, - setUserFlairID:
//   - showUserFlair, - setShowUserFlair:
//   - canSetFlair, - setCanSetFlair:
//   - title
//   - URL
//   - isOver18
//   - isContributor
//   - isModerator
//   - isSubscriber
//   - isBanned
//   - totalSubscribers
//   - acceptedSubmissionsType
//   - allowImagePosts, - setAllowImagePosts:
//   - allowVideoGIFPosts, - setAllowVideoGIFPosts:
//   - allowVideoPosts, - setAllowVideoPosts:
//   - subredditType
//   - commentSpamFilterStrength
//   - linkSpamFilterStrength
//   - selfPostSpamFilterStrength
//   - rules, - setRules:
//   - submitLinkPostLabel
//   - submitTextPostLabel
//   - submitText
//   - submitTextHTML
//   - trafficPagePubliclyAccessible
//   - communityIconURL, - setCommunityIconURL:
//   - iconImageURL, - setIconImageURL:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKSubreddit

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"name": @"data.display_name",
        @"title": @"data.title",
        @"URL": @"data.url",
        @"subredditDescription": @"data.public_description",
        @"subredditDescriptionHTML": @"data.public_description_html",
        @"publicDescription": @"data.public_description",
        @"headerImageURL": @"data.header_img",
        @"headerTitle": @"data.header_title",
        @"iconURL": @"data.icon_img",
        @"communityIconURL": @"data.community_icon",
        @"iconImageURL": @"data.icon_img",
        @"totalSubscribers": @"data.subscribers",
        @"accountsActive": @"data.accounts_active",
        @"isOver18": @"data.over18",
        @"isContributor": @"data.is_contributor",
        @"isModerator": @"data.is_moderator",
        @"isSubscriber": @"data.is_subscriber",
        @"isBanned": @"data.is_banned",
        @"canCrosspostTo": @"data.can_crosspost",
        @"acceptedSubmissionsType": @"data.submission_type",
        @"allowImagePosts": @"data.allow_image_posts",
        @"allowVideoGIFPosts": @"data.allow_video_gif_posts",
        @"allowVideoPosts": @"data.allow_video_posts",
        @"subredditType": @"data.subreddit_type",
        @"commentSpamFilterStrength": @"data.comment_spam_filter_strength",
        @"linkSpamFilterStrength": @"data.link_spam_filter_strength",
        @"selfPostSpamFilterStrength": @"data.selfpost_spam_filter_strength",
        @"rules": @"data.rules",
        @"submitLinkPostLabel": @"data.submit_link_label",
        @"submitTextPostLabel": @"data.submit_text_label",
        @"submitText": @"data.submit_text",
        @"submitTextHTML": @"data.submit_text_html",
        @"trafficPagePubliclyAccessible": @"data.traffic_page_publicly_accessible",
        @"oldSiteColorHexcode": @"data.old_site_color",
        @"redesignColorHexcode": @"data.redesign_color",
        @"userFlairID": @"data.user_flair_id",
        @"showUserFlair": @"data.show_user_flair",
        @"canSetFlair": @"data.can_set_flair",
        @"isEnrolledInNewModmail": @"data.is_enrolled_in_new_modmail",
        @"whitelistStatus": @"data.whitelist_status",
        @"commentScoreHiddenDuration": @"data.comment_score_hidden_duration",
    };
}

+ (NSValueTransformer *)totalSubscribersJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(NSNumber *value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)accountsActiveJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(NSNumber *value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)canCrosspostToJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(NSNumber *value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)headerImageURLJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)communityIconURLJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)iconImageURLJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)acceptedSubmissionsTypeJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)subredditTypeJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)showUserFlairJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return @(((NSNumber *)value).boolValue);} reverseBlock:^id(id value) {
        return @(((NSNumber *)value).boolValue);
    }];
}

+ (NSValueTransformer *)commentSpamFilterStrengthJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return @(((NSNumber *)value).integerValue);} reverseBlock:^id(id value) {
        return @(((NSNumber *)value).integerValue);
    }];
}

+ (NSValueTransformer *)linkSpamFilterStrengthJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return @(((NSNumber *)value).integerValue);} reverseBlock:^id(id value) {
        return @(((NSNumber *)value).integerValue);
    }];
}

+ (NSValueTransformer *)selfPostSpamFilterStrengthJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return @(((NSNumber *)value).integerValue);} reverseBlock:^id(id value) {
        return @(((NSNumber *)value).integerValue);
    }];
}

+ (NSValueTransformer *)spamFilterValueTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return @(((NSNumber *)value).integerValue);} reverseBlock:^id(id value) {
        return @(((NSNumber *)value).integerValue);
    }];
}

+ (NSValueTransformer *)rulesJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<RDKSubreddit: r/%@>", self.name];
}

- (NSString *)iconURL {
    if (self.communityIconURL) {
        return self.communityIconURL;
    }
    return self.iconImageURL;
}

@end
