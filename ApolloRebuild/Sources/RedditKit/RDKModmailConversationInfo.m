#import "RDKModmailConversationInfo.h"

// RDKModmailConversationInfo - Reddit modmail conversation info model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: authors (NSArray *)
//   +0x10: identifier (NSString *)
//   +0x18: isAutomoderator (BOOL)
//   +0x20: isHighlighted (BOOL)
//   +0x28: isInternal (BOOL)
//   +0x30: isRepliable (BOOL)
//   +0x38: lastModeratorUpdate (NSDate *)
//   +0x40: lastUnread (NSDate *)
//   +0x48: lastUpdated (NSDate *)
//   +0x50: lastUserUpdate (NSDate *)
//   +0x58: totalMessages (NSInteger)
//   +0x60: owner (NSString *)
//   +0x68: participant (id)
//   +0x70: state (NSString *)
//   +0x78: subject (NSString *)
//   +0x80: objIDs (NSArray *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - allowedSecureCodingClassesByPropertyKey
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - authorsJSONTransformer (Mantle)
//   - lastModeratorUpdateJSONTransformer (Mantle)
//   - lastUnreadJSONTransformer (Mantle)
//   - lastUpdatedJSONTransformer (Mantle)
//   - lastUserUpdateJSONTransformer (Mantle)
//   - participantJSONTransformer (Mantle)
//   - authors, - setAuthors:
//   - identifier, - setIdentifier:
//   - isAutomoderator, - setIsAutomoderator:
//   - isHighlighted, - setIsHighlighted:
//   - isInternal, - setIsInternal:
//   - isRepliable, - setIsRepliable:
//   - lastModeratorUpdate, - setLastModeratorUpdate:
//   - lastUnread, - setLastUnread:
//   - lastUpdated, - setLastUpdated:
//   - lastUserUpdate, - setLastUserUpdate:
//   - totalMessages, - setTotalMessages:
//   - owner, - setOwner:
//   - participant, - setParticipant:
//   - state, - setState:
//   - subject, - setSubject:
//   - objIDs, - setObjIDs:
//   - .cxx_destruct (ARC cleanup)
//   - diffIdentifier (IGListKit)
//   - isEqualToDiffableObject: (IGListKit)

@implementation RDKModmailConversationInfo

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"authors": @"authors",
        @"identifier": @"id",
        @"isAutomoderator": @"isAuto",
        @"isHighlighted": @"isHighlighted",
        @"isInternal": @"isInternal",
        @"isRepliable": @"isRepliable",
        @"lastModeratorUpdate": @"lastModUpdate",
        @"lastUnread": @"lastUnread",
        @"lastUpdated": @"lastUpdated",
        @"lastUserUpdate": @"lastUserUpdate",
        @"objIDs": @"objIds",
        @"owner": @"owner",
        @"participant": @"participant",
        @"state": @"state",
        @"subject": @"subject",
        @"totalMessages": @"numMessages",
    };
}

+ (NSValueTransformer *)authorsJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)lastModeratorUpdateJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(NSNumber *value) {
        return [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];} reverseBlock:^id(NSDate *value) {
        return @([value timeIntervalSince1970]);
    }];
}

+ (NSValueTransformer *)lastUnreadJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(NSNumber *value) {
        return [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];} reverseBlock:^id(NSDate *value) {
        return @([value timeIntervalSince1970]);
    }];
}

+ (NSValueTransformer *)lastUpdatedJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(NSNumber *value) {
        return [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];} reverseBlock:^id(NSDate *value) {
        return @([value timeIntervalSince1970]);
    }];
}

+ (NSValueTransformer *)lastUserUpdateJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(NSNumber *value) {
        return [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];} reverseBlock:^id(NSDate *value) {
        return @([value timeIntervalSince1970]);
    }];
}

+ (NSValueTransformer *)participantJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

// IGListKit diffing support
- (NSString *)diffIdentifier {
    return self.identifier;
}

- (BOOL)isEqualToDiffableObject:(id)object {
    if (![object isKindOfClass:[RDKModmailConversationInfo class]]) {
        return NO;
    }
    RDKModmailConversationInfo *other = (RDKModmailConversationInfo *)object;
    return [self.identifier isEqualToString:other.identifier] &&
           [self.lastUpdated isEqual:other.lastUpdated];
}

@end
