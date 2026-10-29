#import "RDKAccessToken.h"

// RDKAccessToken - an OAuth token pair from /api/v1/access_token
// Reconstructed from apollo-base 1.15.11 binary analysis.

@implementation RDKAccessToken

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (instancetype)accessTokenWithJSON:(NSDictionary *)JSON {
    if (![JSON isKindOfClass:[NSDictionary class]] || ![JSON[@"access_token"] isKindOfClass:[NSString class]]) {
        return nil;
    }
    RDKAccessToken *token = [[RDKAccessToken alloc] init];
    token.accessToken = JSON[@"access_token"];
    token.refreshToken = [JSON[@"refresh_token"] isKindOfClass:[NSString class]] ? JSON[@"refresh_token"] : nil;
    token.tokenType = [JSON[@"token_type"] isKindOfClass:[NSString class]] ? JSON[@"token_type"] : nil;
    token.scope = [JSON[@"scope"] isKindOfClass:[NSString class]] ? JSON[@"scope"] : nil;
    token.duration = [JSON[@"expires_in"] respondsToSelector:@selector(unsignedLongLongValue)] ? [JSON[@"expires_in"] unsignedLongLongValue] : 3600;
    token.expirationDate = [NSDate dateWithTimeIntervalSinceNow:token.duration];
    return token;
}

- (BOOL)isExpired {
    return self.expirationDate == nil || self.expirationDate.timeIntervalSinceNow < 60;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _accessToken = [coder decodeObjectOfClass:[NSString class] forKey:@"accessToken"];
        _refreshToken = [coder decodeObjectOfClass:[NSString class] forKey:@"refreshToken"];
        _duration = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"duration"] unsignedLongLongValue];
        _tokenType = [coder decodeObjectOfClass:[NSString class] forKey:@"tokenType"];
        _scope = [coder decodeObjectOfClass:[NSString class] forKey:@"scope"];
        _expirationDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"expirationDate"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.accessToken forKey:@"accessToken"];
    [coder encodeObject:self.refreshToken forKey:@"refreshToken"];
    [coder encodeObject:@(self.duration) forKey:@"duration"];
    [coder encodeObject:self.tokenType forKey:@"tokenType"];
    [coder encodeObject:self.scope forKey:@"scope"];
    [coder encodeObject:self.expirationDate forKey:@"expirationDate"];
}

- (NSString *)description {
    // Never log the tokens themselves
    return [NSString stringWithFormat:@"<RDKAccessToken: %p; refreshable = %@, expires = %@>", self, self.refreshToken ? @"YES" : @"NO", self.expirationDate];
}

@end
