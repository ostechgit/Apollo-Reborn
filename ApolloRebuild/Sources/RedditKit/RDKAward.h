#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>
#import "RDKThing.h"

// RDKAward - Reddit award model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKAward : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *awardType;
@property (nonatomic, copy) NSString *awardSubType;
@property (nonatomic, assign) NSInteger coinPrice;
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, copy) NSString *awardDescription;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) BOOL isNew;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) BOOL subredditCoinAward;
@property (nonatomic, copy) NSString *subredditFullname;
@property (nonatomic, strong) NSArray *resizedIcons;
@property (nonatomic, copy) NSString *largeIconURL;
@property (nonatomic, assign) NSInteger largeIconWidth;

@end
