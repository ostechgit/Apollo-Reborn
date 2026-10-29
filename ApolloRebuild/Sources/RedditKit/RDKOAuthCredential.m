#import "RDKOAuthCredential.h"

// RDKOAuthCredential - the Reddit app (client ID + redirect URI) and its current token
// Reconstructed from apollo-base 1.15.11 binary analysis.

@implementation RDKOAuthCredential

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _clientIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"clientIdentifier"];
        _redirectURI = [coder decodeObjectOfClass:[NSURL class] forKey:@"redirectURI"];
        _authorizationCode = [coder decodeObjectOfClass:[NSString class] forKey:@"authorizationCode"];
        _accessToken = [coder decodeObjectOfClass:[RDKAccessToken class] forKey:@"accessToken"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.clientIdentifier forKey:@"clientIdentifier"];
    [coder encodeObject:self.redirectURI forKey:@"redirectURI"];
    [coder encodeObject:self.authorizationCode forKey:@"authorizationCode"];
    [coder encodeObject:self.accessToken forKey:@"accessToken"];
}

@end
