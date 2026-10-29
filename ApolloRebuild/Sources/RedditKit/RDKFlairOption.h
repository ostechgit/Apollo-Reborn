#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKFlairOption - Reddit flair option model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKFlairOption : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, assign) BOOL isEditable;
@property (nonatomic, strong) NSArray *flairs;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *textRepresentation;

@end
