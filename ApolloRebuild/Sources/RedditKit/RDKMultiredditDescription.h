#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKMultiredditDescription - Multireddit description model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKMultiredditDescription : MTLModel <MTLJSONSerializing>

@property (nonatomic, copy) NSString *description;
@property (nonatomic, copy) NSString *bodyHTML;
@property (nonatomic, copy) NSString *bodyMarkdown;

@end
