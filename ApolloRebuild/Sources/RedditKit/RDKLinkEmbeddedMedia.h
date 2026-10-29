#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKLinkEmbeddedMedia - Reddit link embedded media model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKLinkEmbeddedMedia : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *authorName;
@property (nonatomic, copy) NSString *authorURL;
@property (nonatomic, copy) NSString *providerURL;
@property (nonatomic, copy) NSString *providerDescription;
@property (nonatomic, copy) NSString *providerTitle;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) NSInteger thumbnailWidth;
@property (nonatomic, assign) NSInteger thumbnailHeight;
@property (nonatomic, copy) NSString *thumbnailURL;

@end
