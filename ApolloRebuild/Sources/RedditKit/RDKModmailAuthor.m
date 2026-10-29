#import "RDKModmailAuthor.h"

// RDKModmailAuthor - Reddit modmail author model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: identifier (NSString *)
//   +0x10: isAdmin (BOOL)
//   +0x18: isDeleted (BOOL)
//   +0x20: isHidden (BOOL)
//   +0x28: isMod (BOOL)
//   +0x30: isOP (BOOL)
//   +0x38: isParticipant (BOOL)
//   +0x40: name (NSString *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - modelVersion
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - identifier, - setIdentifier:
//   - isAdmin, - setIsAdmin:
//   - isDeleted, - setIsDeleted:
//   - isHidden, - setIsHidden:
//   - isMod, - setIsMod:
//   - isOP, - setIsOP:
//   - isParticipant, - setIsParticipant:
//   - name, - setName:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKModmailAuthor

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSUInteger)modelVersion {
    return 1;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"identifier": @"id",
        @"isAdmin": @"is_admin",
        @"isDeleted": @"is_deleted",
        @"isHidden": @"is_hidden",
        @"isMod": @"is_mod",
        @"isOP": @"is_op",
        @"isParticipant": @"is_participant",
        @"name": @"name",
    };
}

@end
