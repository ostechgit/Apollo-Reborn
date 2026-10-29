#import "RDKMe.h"

// RDKMe - Reddit "me" endpoint model (extends RDKUser)
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Methods recovered:
//   - JSONKeyPathsByPropertyKey (extends RDKUser's with additional fields)
//
// The binary shows this class adds JSON key paths for the /api/v1/me endpoint,
// which includes additional user-specific data beyond the standard user profile.

@implementation RDKMe

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    // Start with RDKUser's key paths
    NSDictionary *base = [super JSONKeyPathsByPropertyKey];
    
    // Add additional key paths for the /api/v1/me endpoint
    // (exact fields would be determined by the binary's NSConstantDictionary)
    return [base mtl_dictionaryByAddingEntriesFromDictionary:@{
        // Additional fields specific to the "me" endpoint
    }];
}

@end
