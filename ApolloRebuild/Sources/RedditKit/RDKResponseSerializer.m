#import "RDKResponseSerializer.h"
#import "RDKClient.h"

// RDKResponseSerializer - JSON responses plus Reddit's error shapes
// Reconstructed from apollo-base 1.15.11 binary analysis.

NSString *const RDKResponseSerializerJSONKey = @"RDKResponseSerializerJSON";

@implementation RDKResponseSerializer

+ (instancetype)serializer {
    RDKResponseSerializer *serializer = [[self alloc] init];
    // Status codes are checked below, so accept everything here
    serializer.acceptableStatusCodes = nil;
    serializer.acceptableContentTypes = nil;
    return serializer;
}

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError **)error {
    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 200;

    id JSON = nil;
    if (data.length > 0) {
        JSON = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    }

    NSString *failure = nil;
    NSInteger code = status;
    if (status < 200 || status >= 300) {
        failure = [NSHTTPURLResponse localizedStringForStatusCode:status];
        if ([JSON isKindOfClass:[NSDictionary class]] && [JSON[@"message"] isKindOfClass:[NSString class]]) {
            failure = JSON[@"message"];
        }
        if ([JSON isKindOfClass:[NSDictionary class]] && [JSON[@"error"] isKindOfClass:[NSString class]]) {
            // e.g. 400/401 {"error": "invalid_grant"} from the token endpoint
            failure = JSON[@"error"];
            code = RDKClientErrorInvalidOAuthGrant;
        }
    } else if ([JSON isKindOfClass:[NSDictionary class]] && [JSON[@"error"] isKindOfClass:[NSString class]]) {
        failure = JSON[@"error"];
        code = RDKClientErrorInvalidOAuthGrant;
    } else if ([JSON isKindOfClass:[NSDictionary class]]) {
        // api_type=json: {"json": {"errors": [["RATELIMIT", "you are doing that too much", "ratelimit"]]}}
        NSDictionary *json = [JSON[@"json"] isKindOfClass:NSDictionary.class] ? JSON[@"json"] : nil;
        NSArray *errors = json[@"errors"];
        if ([errors isKindOfClass:[NSArray class]] && errors.count > 0) {
            NSArray *first = errors.firstObject;
            failure = [first isKindOfClass:[NSArray class]] && first.count > 1 ? [first[1] description] : [first description];
            code = [first isKindOfClass:[NSArray class]] && [first.firstObject isEqual:@"RATELIMIT"] ? RDKClientErrorRateLimited : RDKClientErrorInvalidResponse;
        }
    }

    if (failure) {
        if (error) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:failure forKey:NSLocalizedDescriptionKey];
            userInfo[RDKResponseSerializerJSONKey] = JSON;
            *error = [NSError errorWithDomain:RDKClientErrorDomain code:code userInfo:userInfo];
        }
        return nil;
    }
    return JSON;
}

@end
