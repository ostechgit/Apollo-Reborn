#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>
#import "RDKThing.h"

// RDKMultireddit - Reddit multireddit model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKMultireddit : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *descriptionHTML;
@property (nonatomic, copy) NSString *descriptionMarkdown;
@property (nonatomic, copy) NSString *copiedFrom;
@property (nonatomic, strong) NSArray *subreddits;
@property (nonatomic, assign) BOOL isEditable;
@property (nonatomic, copy) NSString *visibility;
@property (nonatomic, assign) NSTimeInterval createdUTC;
@property (nonatomic, copy) NSString *ownerUsername;

@end
