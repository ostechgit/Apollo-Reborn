#import "RDKFullname.h"

// RDKFullname - Reddit fullname parser
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: fullName (NSString *)
//
// Methods recovered:
//   - initWithFullName:
//   - identifier (extracts ID after ':')
//   - isValid (regex: t[0-9]_[a-zA-Z0-9_-]+)
//   - fullName, - setFullName:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKFullname {
    NSString *_fullName;
}

- (instancetype)initWithFullName:(NSString *)fullName {
    self = [super init];
    if (self) {
        _fullName = [fullName copy];
    }
    return self;
}

- (NSString *)identifier {
    if (![self isValid]) {
        return nil;
    }
    NSArray *components = [_fullName componentsSeparatedByString:@":"];
    return components.lastObject;
}

- (BOOL)isValid {
    if (!_fullName) {
        return NO;
    }
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"t[0-9]_[a-zA-Z0-9_-]+" options:0 error:&error];
    if (error) {
        return NO;
    }
    NSUInteger matches = [regex numberOfMatchesInString:_fullName options:0 range:NSMakeRange(0, _fullName.length)];
    return matches > 0;
}

- (NSString *)fullName {
    return _fullName;
}

- (void)setFullName:(NSString *)fullName {
    _fullName = [fullName copy];
}

@end
