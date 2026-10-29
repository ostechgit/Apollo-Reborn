#import <Foundation/Foundation.h>

// RDKAccessToken - an OAuth token pair from /api/v1/access_token
// Reconstructed from apollo-base 1.15.11 binary analysis.

NS_ASSUME_NONNULL_BEGIN

@interface RDKAccessToken : NSObject <NSSecureCoding>

@property (nonatomic, copy, nullable) NSString *accessToken;
@property (nonatomic, copy, nullable) NSString *refreshToken;  // absent for app-only tokens
@property (nonatomic, assign) unsigned long long duration;     // expires_in, seconds
@property (nonatomic, copy, nullable) NSString *tokenType;
@property (nonatomic, copy, nullable) NSString *scope;
@property (nonatomic, strong, nullable) NSDate *expirationDate;

// Parses a token response; nil without an access_token
+ (nullable instancetype)accessTokenWithJSON:(nullable NSDictionary *)JSON;

// Expired, or about to (a minute's margin, so requests don't race the expiry)
@property (nonatomic, readonly, getter=isExpired) BOOL expired;

@end

NS_ASSUME_NONNULL_END
