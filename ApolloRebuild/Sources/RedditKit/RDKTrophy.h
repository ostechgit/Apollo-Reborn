#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKTrophy - Reddit trophy model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKTrophy : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *description;
@property (nonatomic, copy) NSString *trophyIdentifier;
@property (nonatomic, copy) NSString *trophyName;
@property (nonatomic, copy) NSString *trophyDescription;
@property (nonatomic, copy) NSString *trophyPath;
@property (nonatomic, copy) NSString *smallIconURL;
@property (nonatomic, copy) NSString *largeIconURL;

@end
