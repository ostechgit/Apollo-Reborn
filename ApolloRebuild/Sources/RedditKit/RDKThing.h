#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKThing - base model for every Reddit "thing" (t1 comment, t3 link, ...)
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Hierarchy, as in the original RedditKit fork:
//   RDKThing <- RDKCreated <- RDKVotable <- RDKLink / RDKComment
//
// Models are built from the full {"kind": ..., "data": {...}} object, so key
// paths are "data.<field>".

NS_ASSUME_NONNULL_BEGIN

@interface RDKThing : MTLModel <MTLJSONSerializing>

@property (nonatomic, copy, nullable) NSString *identifier; // data.id, e.g. "1abc2d"
@property (nonatomic, copy, nullable) NSString *fullName;   // data.name, e.g. "t3_1abc2d"
@property (nonatomic, copy, nullable) NSString *kindName;   // kind, e.g. "t3"

// IGListKit-style diffing hooks (the original conforms to IGListDiffable)
- (id<NSObject>)diffIdentifier;
- (BOOL)isEqualToDiffableObject:(nullable id)object;

@end

NS_ASSUME_NONNULL_END
