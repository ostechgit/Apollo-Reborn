#import <Foundation/Foundation.h>
#import "RDKAccessToken.h"

// RDKOAuthCredential - the Reddit app (client ID + redirect URI) and its current token
// Reconstructed from apollo-base 1.15.11 binary analysis.

NS_ASSUME_NONNULL_BEGIN

@interface RDKOAuthCredential : NSObject <NSSecureCoding>

@property (nonatomic, copy, nullable) NSString *clientIdentifier;
@property (nonatomic, copy, nullable) NSURL *redirectURI;
@property (nonatomic, copy, nullable) NSString *authorizationCode;
@property (nonatomic, strong, nullable) RDKAccessToken *accessToken;

@end

NS_ASSUME_NONNULL_END
