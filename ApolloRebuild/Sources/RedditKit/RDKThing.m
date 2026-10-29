#import "RDKThing.h"

// RDKThing - base model for every Reddit "thing"
// Reconstructed from apollo-base 1.15.11 binary analysis.

@implementation RDKThing

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, id> *)JSONKeyPathsByPropertyKey {
    return @{
        @"identifier": @"data.id",
        @"fullName": @"data.name",
        @"kindName": @"kind",
    };
}

// Reddit sends null for plenty of scalar fields ("likes", "view_count", ...).
// Mantle hands those to -setValue:nil forKey:, which throws for scalars and
// would discard the whole model, so treat nil as zero instead.
- (void)setNilValueForKey:(NSString *)key {
    [self setValue:@0 forKey:key];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[RDKThing class]]) {
        return NO;
    }
    NSString *otherFullName = ((RDKThing *)object).fullName;
    return self.fullName != nil && [self.fullName isEqualToString:otherFullName];
}

- (NSUInteger)hash {
    return self.fullName.hash;
}

- (id<NSObject>)diffIdentifier {
    return self.fullName ?: [NSValue valueWithNonretainedObject:self];
}

- (BOOL)isEqualToDiffableObject:(id)object {
    return [self isEqual:object];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p; fullName = %@>", NSStringFromClass(self.class), self, self.fullName];
}

@end
