#import "RDKFlairOption.h"

// RDKFlairOption - Reddit flair option model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: isEditable (BOOL)
//   +0x10: flairs (NSArray *)
//   +0x18: identifier (NSString *)
//   +0x20: textRepresentation (NSString *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - initWithCoder:
//   - encodeWithCoder:
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - flairsJSONTransformer (Mantle)
//   - isEditable, - setIsEditable:
//   - flairs, - setFlairs:
//   - identifier, - setIdentifier:
//   - textRepresentation, - setTextRepresentation:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKFlairOption

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"isEditable": @"is_editable",
        @"flairs": @"flairs",
        @"identifier": @"id",
        @"textRepresentation": @"text_representation",
    };
}

+ (NSValueTransformer *)flairsJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _isEditable = [coder decodeBoolForKey:@"isEditable"];
        _flairs = [coder decodeObjectForKey:@"flairs"];
        _identifier = [coder decodeObjectForKey:@"identifier"];
        _textRepresentation = [coder decodeObjectForKey:@"textRepresentation"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeBool:_isEditable forKey:@"isEditable"];
    [coder encodeObject:_flairs forKey:@"flairs"];
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_textRepresentation forKey:@"textRepresentation"];
}

@end
