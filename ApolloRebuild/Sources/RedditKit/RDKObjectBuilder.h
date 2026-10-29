#import <Foundation/Foundation.h>

// RDKObjectBuilder - turns Reddit JSON "things" into model objects
// Reconstructed from apollo-base 1.15.11 binary analysis.

NS_ASSUME_NONNULL_BEGIN

@interface RDKObjectBuilder : NSObject

+ (instancetype)objectBuilder;

// Model class for a "kind" (t1, t3, more, ...), or nil if unknown
- (nullable Class)classForObjectKind:(nullable NSString *)kind;

// Builds one model from {"kind": ..., "data": {...}}; nil if the kind is unknown or the JSON doesn't fit
- (nullable id)objectFromJSON:(nullable NSDictionary *)JSON;

// Builds every child of {"kind": "Listing", "data": {"children": [...]}}, skipping ones that fail
- (NSArray *)objectsFromListingResponse:(nullable NSDictionary *)listing;

@end

NS_ASSUME_NONNULL_END
