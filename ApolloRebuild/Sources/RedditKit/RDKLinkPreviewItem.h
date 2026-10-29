#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKLinkPreviewItem - Reddit link preview item model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKLinkPreviewItem : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *URL;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;

@end
