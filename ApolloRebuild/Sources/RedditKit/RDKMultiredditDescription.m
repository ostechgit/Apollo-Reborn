#import "RDKMultiredditDescription.h"

// RDKMultiredditDescription - Multireddit description model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: description (NSString *)
//   +0x10: bodyHTML (NSString *)
//   +0x18: bodyMarkdown (NSString *)
//
// Methods recovered:
//   - JSONKeyPathsByPropertyKey (Mantle: bodyHTML -> data.body_html, bodyMarkdown -> data.body_md)
//   - description, - bodyHTML, - bodyMarkdown
//   - .cxx_destruct (ARC cleanup)

@implementation RDKMultiredditDescription

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"bodyHTML": @"data.body_html",
        @"bodyMarkdown": @"data.body_md",
    };
}

@end
