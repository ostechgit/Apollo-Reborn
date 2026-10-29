#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>

// RDKResponseSerializer - JSON responses plus Reddit's error shapes
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Fails with an RDKClientErrorDomain error for a non-2xx status (code = status),
// a token response carrying {"error": "invalid_grant"}, or an api_type=json
// response whose json.errors is non-empty. The parsed JSON is attached under
// RDKResponseSerializerJSONKey.

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const RDKResponseSerializerJSONKey;

@interface RDKResponseSerializer : AFHTTPResponseSerializer

+ (instancetype)serializer;

@end

NS_ASSUME_NONNULL_END
