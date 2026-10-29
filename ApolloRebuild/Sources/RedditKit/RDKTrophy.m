#import "RDKTrophy.h"

// RDKTrophy - Reddit trophy model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: description (NSString *)
//   +0x10: trophyIdentifier (NSString *)
//   +0x18: trophyName (NSString *)
//   +0x20: trophyDescription (NSString *)
//   +0x28: trophyPath (NSString *)
//   +0x30: smallIconURL (NSString *)
//   +0x38: largeIconURL (NSString *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - modelVersion
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - description
//   - trophyIdentifier
//   - trophyName
//   - trophyDescription
//   - trophyPath
//   - smallIconURL
//   - largeIconURL
//   - .cxx_destruct (ARC cleanup)

@implementation RDKTrophy

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSUInteger)modelVersion {
    return 1;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"description": @"description",
        @"trophyIdentifier": @"id",
        @"trophyName": @"name",
        @"trophyDescription": @"description",
        @"trophyPath": @"path",
        @"smallIconURL": @"icon1",
        @"largeIconURL": @"icon2",
    };
}

@end
