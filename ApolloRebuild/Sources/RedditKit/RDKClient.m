#import "RDKClient.h"
#import "RDKObjectBuilder.h"
#import "RDKResponseSerializer.h"
#import "RDKSubreddit.h"

// RDKClient - the Reddit API client (Apollo's RedditKit fork)
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Recovered details: base URLs, the listing paths ("%@.json", "r/all/%@.json",
// "r/%@/%@.json", "comments/%@.json"), comments' sort/limit/depth=20 parameters,
// api/vote's direction table, and the raw_json / api_type parameters added in
// -taskWithMethod:path:parameters:completion:.

NSErrorDomain const RDKClientErrorDomain = @"RDKClientErrorDomain";
NSNotificationName const RDKClientAuthorizationDidChangeNotification = @"RDKClientAuthorizationDidChangeNotification";

// The original keeps each account's client in the keychain (Valet); this rebuild
// persists the shared client in NSUserDefaults for now, which an ad-hoc-signed
// simulator build can also use.
static NSString *const RDKClientArchiveKey = @"RDKClientArchive";
static NSString *const RDKDeviceIdentifierKey = @"RDKDeviceIdentifier";

@interface RDKClient ()
// Work waiting on a token refresh or app-only authentication
@property (nonatomic, strong) NSMutableArray<void (^)(NSError *_Nullable)> *queuedOperations;
@property (nonatomic, copy, readwrite, nullable) NSString *lastCommentsAfterCursor;
@end

@implementation RDKClient

+ (instancetype)sharedClient {
    static RDKClient *client;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSData *archive = [[NSUserDefaults standardUserDefaults] dataForKey:RDKClientArchiveKey];
        if (archive) {
            client = [NSKeyedUnarchiver unarchivedObjectOfClass:[RDKClient class] fromData:archive error:nil];
        }
        if (!client) {
            client = [[RDKClient alloc] init];
        }
        [[NSNotificationCenter defaultCenter] addObserverForName:RDKClientAuthorizationDidChangeNotification object:client queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:client requiringSecureCoding:YES error:nil];
            [[NSUserDefaults standardUserDefaults] setObject:data forKey:RDKClientArchiveKey];
        }];
    });
    return client;
}

// RDK_API_BASE_URL / RDK_OAUTH_BASE_URL point the client at a local mock server
// (tests/mock_reddit_server.py) so the auth and listing flow can be tested without
// a Reddit app. Unset in normal use.
+ (NSURL *)APIBaseURL {
    NSString *override = [NSProcessInfo processInfo].environment[@"RDK_API_BASE_URL"];
    return [NSURL URLWithString:override.length > 0 ? override : @"https://www.reddit.com/"];
}

+ (NSURL *)APIBaseOAuthURL {
    NSString *override = [NSProcessInfo processInfo].environment[@"RDK_OAUTH_BASE_URL"];
    return [NSURL URLWithString:override.length > 0 ? override : @"https://oauth.reddit.com/"];
}

+ (NSArray<NSString *> *)allScopes {
    return @[@"identity", @"edit", @"flair", @"history", @"modconfig", @"modflair", @"modlog", @"modposts", @"modwiki",
             @"mysubreddits", @"privatemessages", @"read", @"report", @"save", @"submit", @"subscribe", @"vote",
             @"wikiedit", @"wikiread"];
}

- (instancetype)init {
    self = [super initWithBaseURL:[[self class] APIBaseOAuthURL]];
    if (self) {
        self.requestSerializer = [AFHTTPRequestSerializer serializer];
        self.responseSerializer = [RDKResponseSerializer serializer];
        _queuedOperations = [NSMutableArray array];

        // Apollo Reborn's default (Defaults.m defaultUserAgent), the User-Agent known to work
        // with user API keys. AccountManager replaces it with the user's override, if any.
        _userAgent = @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36";
    }
    return self;
}

// MARK: - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [self init];
    if (self) {
        _authorizationCredential = [coder decodeObjectOfClass:[RDKOAuthCredential class] forKey:@"authorizationCredential"];
        _clientSecret = [coder decodeObjectOfClass:[NSString class] forKey:@"clientSecret"];
        _usesApplicationOnlyOAuth = [coder decodeBoolForKey:@"usesApplicationOnlyOAuth"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.authorizationCredential forKey:@"authorizationCredential"];
    [coder encodeObject:self.clientSecret forKey:@"clientSecret"];
    [coder encodeBool:self.usesApplicationOnlyOAuth forKey:@"usesApplicationOnlyOAuth"];
}

// MARK: - Configuration and state

- (void)authenticateWithClientIdentifier:(NSString *)clientIdentifier redirectURI:(NSURL *)redirectURI {
    if (![self.authorizationCredential.clientIdentifier isEqualToString:clientIdentifier]) {
        // Tokens belong to one Reddit app
        self.authorizationCredential = [[RDKOAuthCredential alloc] init];
        self.usesApplicationOnlyOAuth = NO;
    }
    self.authorizationCredential.clientIdentifier = clientIdentifier;
    self.authorizationCredential.redirectURI = redirectURI;
    [self postAuthorizationChange];
}

- (BOOL)hasClientIdentifier {
    return self.authorizationCredential.clientIdentifier.length > 0;
}

- (BOOL)isAuthenticated {
    return self.authorizationCredential.accessToken.accessToken != nil;
}

- (BOOL)isAuthenticatedWithOAuth {
    return !self.usesApplicationOnlyOAuth && self.authorizationCredential.accessToken.refreshToken != nil;
}

- (void)postAuthorizationChange {
    [[NSNotificationCenter defaultCenter] postNotificationName:RDKClientAuthorizationDidChangeNotification object:self];
}

// MARK: - Signing in

- (NSURL *)authorizationURLWithState:(NSString *)state {
    if (!self.hasClientIdentifier || !self.authorizationCredential.redirectURI) {
        return nil;
    }
    NSURL *authorizeURL = [NSURL URLWithString:@"api/v1/authorize.compact" relativeToURL:[[self class] APIBaseURL]];
    NSURLComponents *components = [NSURLComponents componentsWithURL:authorizeURL resolvingAgainstBaseURL:YES];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"client_id" value:self.authorizationCredential.clientIdentifier],
        [NSURLQueryItem queryItemWithName:@"response_type" value:@"code"],
        [NSURLQueryItem queryItemWithName:@"state" value:state],
        [NSURLQueryItem queryItemWithName:@"redirect_uri" value:self.authorizationCredential.redirectURI.absoluteString],
        [NSURLQueryItem queryItemWithName:@"duration" value:@"permanent"],
        [NSURLQueryItem queryItemWithName:@"scope" value:[[[self class] allScopes] componentsJoinedByString:@" "]],
    ];
    return components.URL;
}

- (NSURLSessionDataTask *)signInWithAuthorizationCode:(NSString *)code completion:(RDKCompletionBlock)completion {
    NSDictionary *parameters = @{
        @"grant_type": @"authorization_code",
        @"code": code,
        @"redirect_uri": self.authorizationCredential.redirectURI.absoluteString ?: @"",
    };
    return [self tokenTaskWithParameters:parameters completion:^(RDKAccessToken *token, NSError *error) {
        if (token) {
            self.authorizationCredential.accessToken = token;
            self.usesApplicationOnlyOAuth = NO;
            [self postAuthorizationChange];
        }
        completion(error);
    }];
}

- (NSURLSessionDataTask *)authenticateApplicationOnlyWithCompletion:(RDKCompletionBlock)completion {
    // Installed apps (no secret) use installed_client with a stable device ID;
    // web/script apps use client_credentials
    NSDictionary *parameters;
    if (self.clientSecret.length == 0) {
        parameters = @{@"grant_type": @"https://oauth.reddit.com/grants/installed_client", @"device_id": [self deviceIdentifier]};
    } else {
        parameters = @{@"grant_type": @"client_credentials"};
    }
    return [self tokenTaskWithParameters:parameters completion:^(RDKAccessToken *token, NSError *error) {
        if (token) {
            self.authorizationCredential.accessToken = token;
            self.usesApplicationOnlyOAuth = YES;
            [self postAuthorizationChange];
        }
        completion(error);
    }];
}

- (NSURLSessionDataTask *)refreshAccessTokenWithCompletion:(RDKCompletionBlock)completion {
    NSString *refreshToken = self.authorizationCredential.accessToken.refreshToken;
    return [self tokenTaskWithParameters:@{@"grant_type": @"refresh_token", @"refresh_token": refreshToken ?: @""} completion:^(RDKAccessToken *token, NSError *error) {
        if (token) {
            // Refresh responses don't repeat the refresh token
            token.refreshToken = token.refreshToken ?: refreshToken;
            self.authorizationCredential.accessToken = token;
            [self postAuthorizationChange];
        }
        completion(error);
    }];
}

- (void)signOutWithCompletion:(RDKCompletionBlock)completion {
    NSString *refreshToken = self.authorizationCredential.accessToken.refreshToken;
    if (refreshToken && !self.usesApplicationOnlyOAuth) {
        // Best effort: the account is forgotten locally either way
        NSMutableURLRequest *request = [self tokenEndpointRequestWithPath:@"api/v1/revoke_token" parameters:@{@"token": refreshToken, @"token_type_hint": @"refresh_token"}];
        [[self dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:nil] resume];
    }
    self.authorizationCredential.accessToken = nil;
    self.usesApplicationOnlyOAuth = NO;
    [self postAuthorizationChange];
    if (completion) {
        completion(nil);
    }
}

- (NSURLSessionDataTask *)currentUserWithCompletion:(RDKObjectCompletionBlock)completion {
    if (!self.isAuthenticatedWithOAuth) {
        completion(nil, [self errorWithCode:RDKClientErrorAuthenticationRequired description:@"No Reddit account is signed in."]);
        return nil;
    }
    return [self getPath:@"api/v1/me" parameters:nil completion:completion];
}

// MARK: - Token endpoint

- (NSString *)deviceIdentifier {
    NSString *identifier = [[NSUserDefaults standardUserDefaults] stringForKey:RDKDeviceIdentifierKey];
    if (!identifier) {
        identifier = [NSUUID UUID].UUIDString;
        [[NSUserDefaults standardUserDefaults] setObject:identifier forKey:RDKDeviceIdentifierKey];
    }
    return identifier;
}

- (NSMutableURLRequest *)tokenEndpointRequestWithPath:(NSString *)path parameters:(NSDictionary *)parameters {
    NSString *URLString = [NSURL URLWithString:path relativeToURL:[[self class] APIBaseURL]].absoluteString;
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:@"POST" URLString:URLString parameters:parameters error:nil];
    NSString *credentials = [NSString stringWithFormat:@"%@:%@", self.authorizationCredential.clientIdentifier ?: @"", self.clientSecret ?: @""];
    NSString *basic = [[credentials dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    [request setValue:[@"Basic " stringByAppendingString:basic] forHTTPHeaderField:@"Authorization"];
    [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    return request;
}

- (NSURLSessionDataTask *)tokenTaskWithParameters:(NSDictionary *)parameters completion:(void (^)(RDKAccessToken *token, NSError *error))completion {
    if (!self.hasClientIdentifier) {
        completion(nil, [self errorWithCode:RDKClientErrorAuthenticationRequired description:@"No Reddit API client ID is configured."]);
        return nil;
    }
    NSMutableURLRequest *request = [self tokenEndpointRequestWithPath:@"api/v1/access_token" parameters:parameters];
    NSURLSessionDataTask *task = [self dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        RDKAccessToken *token = error ? nil : [RDKAccessToken accessTokenWithJSON:responseObject];
        if (!token && !error) {
            error = [self errorWithCode:RDKClientErrorInvalidResponse description:@"Reddit's token response had no access token."];
        }
        if (error) {
            NSLog(@"[RDKClient] token request (%@) failed: %@ (%ld)", parameters[@"grant_type"], error.localizedDescription, (long)error.code);
        }
        completion(token, error);
    }];
    [task resume];
    return task;
}

// Runs `block` once there is a usable token: refreshes the account's token, or
// gets an app-only one when logged out. Concurrent callers share one request.
- (void)ensureValidTokenThen:(void (^)(NSError *_Nullable error))block {
    [self.queuedOperations addObject:[block copy]];
    if (self.refreshingToken) {
        return;
    }
    self.refreshingToken = YES;

    RDKCompletionBlock finish = ^(NSError *error) {
        self.refreshingToken = NO;
        NSArray *queued = [self.queuedOperations copy];
        [self.queuedOperations removeAllObjects];
        for (void (^operation)(NSError *) in queued) {
            operation(error);
        }
    };

    if (!self.usesApplicationOnlyOAuth && self.authorizationCredential.accessToken.refreshToken) {
        [self refreshAccessTokenWithCompletion:finish];
    } else {
        [self authenticateApplicationOnlyWithCompletion:finish];
    }
}

// MARK: - Generic requests

- (NSURLSessionDataTask *)getPath:(NSString *)path parameters:(NSDictionary *)parameters completion:(RDKObjectCompletionBlock)completion {
    return [self taskWithMethod:@"GET" path:path parameters:parameters completion:completion];
}

- (NSURLSessionDataTask *)postPath:(NSString *)path parameters:(NSDictionary *)parameters completion:(RDKObjectCompletionBlock)completion {
    return [self taskWithMethod:@"POST" path:path parameters:parameters completion:completion];
}

- (NSURLSessionDataTask *)taskWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters completion:(RDKObjectCompletionBlock)completion {
    return [self taskWithMethod:method path:path parameters:parameters retryOnUnauthorized:YES completion:completion];
}

- (NSURLSessionDataTask *)taskWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters retryOnUnauthorized:(BOOL)retry completion:(RDKObjectCompletionBlock)completion {
    if (!self.hasClientIdentifier) {
        completion(nil, [self errorWithCode:RDKClientErrorAuthenticationRequired description:@"No Reddit API client ID is configured."]);
        return nil;
    }

    RDKAccessToken *token = self.authorizationCredential.accessToken;
    if (!token.accessToken || token.isExpired) {
        // The task this returns is created later, so there is nothing to hand back yet
        [self ensureValidTokenThen:^(NSError *error) {
            if (error) {
                completion(nil, error);
            } else {
                [self taskWithMethod:method path:path parameters:parameters retryOnUnauthorized:retry completion:completion];
            }
        }];
        return nil;
    }

    NSMutableDictionary *allParameters = [NSMutableDictionary dictionaryWithDictionary:parameters ?: @{}];
    allParameters[@"raw_json"] = @"1";
    if (![method isEqualToString:@"GET"]) {
        allParameters[@"api_type"] = @"json";
    }

    NSString *URLString = [NSURL URLWithString:path relativeToURL:self.baseURL].absoluteString;
    NSError *serializationError = nil;
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:method URLString:URLString parameters:allParameters error:&serializationError];
    if (!request) {
        completion(nil, serializationError);
        return nil;
    }
    [request setValue:[@"bearer " stringByAppendingString:token.accessToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];

    NSURLSessionDataTask *task = [self dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
        [self updateRateLimitsFromResponse:HTTPResponse];

        if (HTTPResponse.statusCode == 401 && retry) {
            // The token stopped working before its expiry; refresh once and retry
            token.expirationDate = [NSDate distantPast];
            [self taskWithMethod:method path:path parameters:parameters retryOnUnauthorized:NO completion:completion];
            return;
        }
        completion(error ? nil : responseObject, error);
    }];
    [task resume];
    return task;
}

- (void)updateRateLimitsFromResponse:(NSHTTPURLResponse *)response {
    NSDictionary *headers = response.allHeaderFields;
    NSString *remaining = headers[@"x-ratelimit-remaining"] ?: headers[@"X-Ratelimit-Remaining"];
    if (remaining) {
        self.rateLimitedRequestsRemaining = (unsigned long long)remaining.doubleValue;
        self.rateLimitedRequestsUsed = (unsigned long long)[(headers[@"x-ratelimit-used"] ?: headers[@"X-Ratelimit-Used"]) doubleValue];
        self.timeUntilRateLimitReset = [(headers[@"x-ratelimit-reset"] ?: headers[@"X-Ratelimit-Reset"]) doubleValue];
    }
}

- (NSError *)errorWithCode:(RDKClientErrorCode)code description:(NSString *)description {
    return [NSError errorWithDomain:RDKClientErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: description}];
}

// MARK: - Listings

- (NSArray *)objectsFromListingResponse:(NSDictionary *)response {
    return [[RDKObjectBuilder objectBuilder] objectsFromListingResponse:response];
}

- (NSURLSessionDataTask *)listingTaskWithPath:(NSString *)path parameters:(NSDictionary *)parameters pagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    NSMutableDictionary *allParameters = [NSMutableDictionary dictionaryWithDictionary:parameters ?: @{}];
    [allParameters addEntriesFromDictionary:pagination.dictionaryValue ?: @{}];

    return [self getPath:path parameters:allParameters completion:^(id response, NSError *error) {
        if (error) {
            completion(nil, nil, error);
            return;
        }
        if (![response isKindOfClass:[NSDictionary class]]) {
            completion(nil, nil, [self errorWithCode:RDKClientErrorInvalidResponse description:@"Expected a listing."]);
            return;
        }
        RDKPagination *next = [RDKPagination paginationFromListingResponse:response];
        // Keep the caller's page size and sort for the next page
        next.limit = pagination.limit;
        next.timeMethod = pagination.timeMethod;
        next.userContentSortingMethod = pagination.userContentSortingMethod;
        completion([self objectsFromListingResponse:response], next, nil);
    }];
}

- (NSURLSessionDataTask *)frontPageLinksWithCategory:(RDKSubredditCategory)category pagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    NSString *path = [NSString stringWithFormat:@"%@.json", RDKStringFromSubredditCategory(category)];
    return [self listingTaskWithPath:path parameters:nil pagination:pagination completion:completion];
}

- (NSURLSessionDataTask *)linksInAllSubredditsWithCategory:(RDKSubredditCategory)category pagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    NSString *path = [NSString stringWithFormat:@"r/all/%@.json", RDKStringFromSubredditCategory(category)];
    return [self listingTaskWithPath:path parameters:nil pagination:pagination completion:completion];
}

- (NSURLSessionDataTask *)linksInSubredditWithName:(NSString *)subredditName category:(RDKSubredditCategory)category pagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    NSString *path = [NSString stringWithFormat:@"r/%@/%@.json", subredditName, RDKStringFromSubredditCategory(category)];
    return [self listingTaskWithPath:path parameters:nil pagination:pagination completion:completion];
}

- (NSURLSessionDataTask *)linksInMultiredditWithPath:(NSString *)path category:(RDKSubredditCategory)category pagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    NSString *trimmed = [path stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    NSString *listingPath = [NSString stringWithFormat:@"%@/%@.json", trimmed, RDKStringFromSubredditCategory(category)];
    return [self listingTaskWithPath:listingPath parameters:nil pagination:pagination completion:completion];
}

- (NSURLSessionDataTask *)submittedLinksByUserWithUsername:(NSString *)username pagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    NSString *path = [NSString stringWithFormat:@"user/%@/submitted.json", username];
    return [self listingTaskWithPath:path parameters:nil pagination:pagination completion:completion];
}

// MARK: - Comments

- (NSDictionary *)commentParametersWithSort:(RDKCommentSortingMethod)sort limit:(NSInteger)limit {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObject:@20 forKey:@"depth"];
    NSString *sortName = RDKStringFromCommentSortingMethod(sort);
    if (sortName) {
        parameters[@"sort"] = sortName;
    }
    if (limit > 0) {
        parameters[@"limit"] = @(limit);
    }
    return parameters;
}

- (NSURLSessionDataTask *)commentsForLinkWithIdentifier:(NSString *)identifier sort:(RDKCommentSortingMethod)sort limit:(NSInteger)limit completion:(RDKArrayCompletionBlock)completion {
    return [self linkAndCommentsTaskWithIdentifier:identifier parameters:[self commentParametersWithSort:sort limit:limit] completion:^(RDKLink *link, NSArray *comments, NSError *error) {
        completion(comments, error);
    }];
}

- (NSURLSessionDataTask *)linkAndCommentsForLinkWithIdentifier:(NSString *)identifier commentSort:(RDKCommentSortingMethod)sort pagination:(RDKPagination *)pagination completion:(RDKLinkAndCommentsCompletionBlock)completion {
    NSMutableDictionary *parameters = [[self commentParametersWithSort:sort limit:(NSInteger)pagination.limit] mutableCopy];
    return [self linkAndCommentsTaskWithIdentifier:identifier parameters:parameters completion:completion];
}

- (NSURLSessionDataTask *)linkAndCommentsTaskWithIdentifier:(NSString *)identifier parameters:(NSDictionary *)parameters completion:(RDKLinkAndCommentsCompletionBlock)completion {
    // Accept a fullname ("t3_abc") or a bare ID
    NSString *bareIdentifier = [identifier hasPrefix:@"t3_"] ? [identifier substringFromIndex:3] : identifier;
    NSString *path = [NSString stringWithFormat:@"comments/%@.json", bareIdentifier];

    return [self linkAndCommentsTaskWithPath:path parameters:parameters completion:completion];
}

// Native 0x100039968: focused path rather than api/morechildren.
- (NSURLSessionDataTask *)linkAndContext:(NSInteger)context forCommentWithIdentifier:(NSString *)commentIdentifier linkIdentifier:(NSString *)linkIdentifier commentSort:(RDKCommentSortingMethod)sort pagination:(RDKPagination *)pagination completion:(RDKLinkAndCommentsCompletionBlock)completion {
    NSString *post = [linkIdentifier hasPrefix:@"t3_"] ? [linkIdentifier substringFromIndex:3] : linkIdentifier;
    NSString *comment = [commentIdentifier hasPrefix:@"t1_"] ? [commentIdentifier substringFromIndex:3] : commentIdentifier;
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"] invertedSet];
    if (!post.length || !comment.length || [post rangeOfCharacterFromSet:invalid].location != NSNotFound || [comment rangeOfCharacterFromSet:invalid].location != NSNotFound || context < 0) {
        completion(nil, nil, [self errorWithCode:RDKClientErrorInvalidResponse description:@"Invalid comment context target."]);
        return nil;
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObject:@(context) forKey:@"context"];
    NSString *sortName = RDKStringFromCommentSortingMethod(sort);
    if (sortName) { parameters[@"sort"] = sortName; }
    if (pagination.limit > 0) { parameters[@"limit"] = @(pagination.limit); }
    NSString *path = [NSString stringWithFormat:@"comments/%@/_/%@.json", post, comment];
    return [self linkAndCommentsTaskWithPath:path parameters:parameters completion:completion];
}

- (NSURLSessionDataTask *)linkAndCommentsTaskWithPath:(NSString *)path parameters:(NSDictionary *)parameters completion:(RDKLinkAndCommentsCompletionBlock)completion {
    return [self getPath:path parameters:parameters completion:^(id response, NSError *error) {
        if (error) {
            completion(nil, nil, error);
            return;
        }
        // [link listing, comment listing]
        if (![response isKindOfClass:[NSArray class]] || [response count] < 2) {
            completion(nil, nil, [self errorWithCode:RDKClientErrorInvalidResponse description:@"Expected a link and its comments."]);
            return;
        }
        RDKLink *link = [self objectsFromListingResponse:response[0]].firstObject;
        NSArray *comments = [self objectsFromListingResponse:response[1]];
        // Remember the listing's cursor; without it the screen can never page.
        NSDictionary *commentData = [response[1] isKindOfClass:NSDictionary.class] ? response[1][@"data"] : nil;
        self.lastCommentsAfterCursor = [commentData[@"after"] isKindOfClass:NSString.class] ? commentData[@"after"] : nil;
        completion([link isKindOfClass:[RDKLink class]] ? link : nil, comments, nil);
    }];
}

// Native 0x10003eab4/0x10003ebb8: context-only request, final Listing.
- (NSURLSessionDataTask *)context:(NSUInteger)context forComment:(RDKComment *)comment completion:(RDKArrayCompletionBlock)completion {
    NSString *post = comment.linkID;
    if ([post hasPrefix:@"t3_"]) { post = [post substringFromIndex:3]; }
    NSString *identifier = comment.identifier;
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"] invertedSet];
    if (!post.length || !identifier.length || [post rangeOfCharacterFromSet:invalid].location != NSNotFound || [identifier rangeOfCharacterFromSet:invalid].location != NSNotFound) {
        completion(nil, [self errorWithCode:RDKClientErrorInvalidResponse description:@"Invalid parent comment target."]);
        return nil;
    }
    return [self getPath:[NSString stringWithFormat:@"comments/%@/_/%@.json", post, identifier] parameters:@{@"context": @(context)} completion:^(id response, NSError *error) {
        if (error) { completion(nil, error); return; }
        id listing = [response isKindOfClass:NSArray.class] ? [response lastObject] : response;
        if (![listing isKindOfClass:NSDictionary.class] || ![listing[@"kind"] isEqual:@"Listing"]) {
            completion(nil, [self errorWithCode:RDKClientErrorInvalidResponse description:@"Expected parent comments."]);
            return;
        }
        completion([self objectsFromListingResponse:listing], nil);
    }];
}

- (NSURLSessionDataTask *)moreComments:(RDKMoreComments *)moreComments forLink:(RDKLink *)link sort:(RDKCommentSortingMethod)sort completion:(RDKArrayCompletionBlock)completion {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:@{
        @"link_id": link.fullName ?: @"",
        @"children": [moreComments.children componentsJoinedByString:@","] ?: @"",
        @"limit_children": @"false",
    }];
    NSString *sortName = RDKStringFromCommentSortingMethod(sort);
    if (sortName) {
        parameters[@"sort"] = sortName;
    }
    return [self postPath:@"api/morechildren" parameters:parameters completion:^(id response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSArray *things = [response isKindOfClass:[NSDictionary class]] ? [response valueForKeyPath:@"json.data.things"] : nil;
        if (![things isKindOfClass:[NSArray class]]) {
            completion(nil, [self errorWithCode:RDKClientErrorInvalidResponse description:@"Expected more comments."]);
            return;
        }
        NSMutableArray *objects = [NSMutableArray arrayWithCapacity:things.count];
        for (NSDictionary *thing in things) {
            id object = [[RDKObjectBuilder objectBuilder] objectFromJSON:thing];
            if (object) {
                [objects addObject:object];
            }
        }
        completion(objects, nil);
    }];
}

// Original funnel: 0x10003e574; auth/write helper: 0x100006fa4.
- (NSURLSessionDataTask *)submitComment:(NSString *)text onThingWithFullName:(NSString *)fullName completion:(void (^)(RDKComment *, NSError *))completion {
    if (!self.isAuthenticatedWithOAuth) {
        completion(nil, [self errorWithCode:RDKClientErrorAuthenticationRequired description:@"Sign in to a Reddit account to do that."]);
        return nil;
    }
    if (![text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length ||
        fullName.length <= 3 || !([fullName hasPrefix:@"t1_"] || [fullName hasPrefix:@"t3_"])) {
        completion(nil, [self errorWithCode:RDKClientErrorInvalidResponse description:@"A reply needs text and a post or comment target."]);
        return nil;
    }
    // Refresh expired tokens before sending, but never replay this write after
    // a response or network failure. Keep the draft and let the user decide.
    return [self taskWithMethod:@"POST" path:@"api/comment" parameters:@{@"text": text, @"thing_id": fullName} retryOnUnauthorized:NO completion:^(id response, NSError *error) {
        if (error) { completion(nil, error); return; }
        NSDictionary *json = [response isKindOfClass:NSDictionary.class] ? response[@"json"] : nil;
        if (![json isKindOfClass:NSDictionary.class]) {
            completion(nil, [self errorWithCode:RDKClientErrorInvalidResponse description:@"Reddit returned an invalid comment response."]);
            return;
        }
        NSArray *errors = [json[@"errors"] isKindOfClass:NSArray.class] ? json[@"errors"] : nil;
        if (errors.count) {
            NSArray *first = [errors.firstObject isKindOfClass:NSArray.class] ? errors.firstObject : nil;
            NSString *message = first.count > 1 && [first[1] isKindOfClass:NSString.class] ? first[1] : @"Reddit could not submit the comment.";
            completion(nil, [self errorWithCode:RDKClientErrorInvalidResponse description:message]);
            return;
        }
        NSDictionary *data = [json[@"data"] isKindOfClass:NSDictionary.class] ? json[@"data"] : nil;
        NSArray *things = [data[@"things"] isKindOfClass:NSArray.class] ? data[@"things"] : nil;
        id thing = things.firstObject;
        NSDictionary *fields = [thing isKindOfClass:NSDictionary.class] && [thing[@"data"] isKindOfClass:NSDictionary.class] ? thing[@"data"] : nil;
        NSString *identifier = [fields[@"id"] isKindOfClass:NSString.class] ? fields[@"id"] : nil;
        NSString *name = [fields[@"name"] isKindOfClass:NSString.class] ? fields[@"name"] : nil;
        NSString *parent = [fields[@"parent_id"] isKindOfClass:NSString.class] ? fields[@"parent_id"] : nil;
        BOOL validIdentity = identifier.length && [name isEqualToString:[@"t1_" stringByAppendingString:identifier]] && [parent isEqualToString:fullName];
        RDKComment *comment = validIdentity ? [[RDKObjectBuilder objectBuilder] objectFromJSON:thing] : nil;
        if (![comment isKindOfClass:RDKComment.class]) {
            completion(nil, [self errorWithCode:RDKClientErrorInvalidResponse description:@"Reddit did not return the submitted comment. Check the thread before trying again."]);
            return;
        }
        completion(comment, nil);
    }];
}

// MARK: - Reporting

// Captured payloads (see RDKClient.h). The reason key holds the selector name
// for admin reasons and the rule text for subreddit rules.
- (NSURLSessionDataTask *)reportThingWithFullname:(NSString *)fullname siteReason:(NSString *)siteReason completion:(RDKCompletionBlock)completion {
    if (!self.isAuthenticatedWithOAuth) {
        completion([self errorWithCode:RDKClientErrorAuthenticationRequired description:@"Sign in to a Reddit account to do that."]);
        return nil;
    }
    if (!fullname.length || !siteReason.length) {
        completion([self errorWithCode:RDKClientErrorInvalidResponse description:@"A report needs a target and a reason."]);
        return nil;
    }
    return [self accountTaskWithPath:@"api/report" parameters:@{
        @"thing_id": fullname,
        @"reason": @"site_reason_selected",
        @"site_reason": siteReason,
    } completion:completion];
}

- (NSURLSessionDataTask *)reportThingWithFullname:(NSString *)fullname ruleReason:(NSString *)ruleName completion:(RDKCompletionBlock)completion {
    if (!self.isAuthenticatedWithOAuth) {
        completion([self errorWithCode:RDKClientErrorAuthenticationRequired description:@"Sign in to a Reddit account to do that."]);
        return nil;
    }
    if (!fullname.length || !ruleName.length) {
        completion([self errorWithCode:RDKClientErrorInvalidResponse description:@"A report needs a target and a rule."]);
        return nil;
    }
    return [self accountTaskWithPath:@"api/report" parameters:@{
        @"thing_id": fullname,
        @"reason": ruleName,
        @"rule_reason": ruleName,
    } completion:completion];
}

// MARK: - Comment pagination

- (NSURLSessionDataTask *)commentsPageForLinkWithIdentifier:(NSString *)identifier sort:(RDKCommentSortingMethod)sort after:(NSString *)after completion:(void (^)(NSArray<RDKThing *> *, NSString *, NSError *))completion {
    NSString *bare = [identifier hasPrefix:@"t3_"] ? [identifier substringFromIndex:3] : identifier;
    if (!bare.length) {
        completion(nil, nil, [self errorWithCode:RDKClientErrorInvalidResponse description:@"A post is required."]);
        return nil;
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObject:@20 forKey:@"depth"];
    NSString *sortName = RDKStringFromCommentSortingMethod(sort);
    if (sortName) { parameters[@"sort"] = sortName; }
    if (after.length) { parameters[@"after"] = after; }
    NSString *path = [NSString stringWithFormat:@"comments/%@.json", bare];
    return [self getPath:path parameters:parameters completion:^(id response, NSError *error) {
        if (error) { completion(nil, nil, error); return; }
        NSArray *listings = [response isKindOfClass:NSArray.class] ? (NSArray *)response : nil;
        if (listings.count < 2) {
            completion(nil, nil, [self errorWithCode:RDKClientErrorInvalidResponse description:@"Expected a comment listing."]);
            return;
        }
        id listing = listings[1];
        NSArray *things = [self objectsFromListingResponse:listing];
        NSDictionary *data = [listing isKindOfClass:NSDictionary.class] ? listing[@"data"] : nil;
        NSString *next = [data[@"after"] isKindOfClass:NSString.class] ? data[@"after"] : nil;
        completion(things, next, nil);
    }];
}

// MARK: - Subreddit rules

- (NSURLSessionDataTask *)rulesForSubreddit:(NSString *)subreddit completion:(void (^)(NSArray<NSDictionary *> *, NSError *))completion {
    if (!subreddit.length) {
        completion(nil, [self errorWithCode:RDKClientErrorInvalidResponse description:@"A subreddit is required."]);
        return nil;
    }
    NSString *path = [NSString stringWithFormat:@"r/%@/about/rules.json", subreddit];
    return [self getPath:path parameters:nil completion:^(id response, NSError *error) {
        if (error) { completion(nil, error); return; }
        NSArray *rules = [response isKindOfClass:NSDictionary.class] && [response[@"rules"] isKindOfClass:NSArray.class]
            ? response[@"rules"] : nil;
        completion([rules filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id rule, NSDictionary *bindings) {
            return [rule isKindOfClass:NSDictionary.class] && [rule[@"short_name"] isKindOfClass:NSString.class];
        }]], nil);
    }];
}

// MARK: - Voting and saving

- (NSURLSessionDataTask *)accountTaskWithPath:(NSString *)path parameters:(NSDictionary *)parameters completion:(RDKCompletionBlock)completion {
    if (!self.isAuthenticatedWithOAuth) {
        completion([self errorWithCode:RDKClientErrorAuthenticationRequired description:@"Sign in to a Reddit account to do that."]);
        return nil;
    }
    return [self postPath:path parameters:parameters completion:^(id response, NSError *error) {
        completion(error);
    }];
}

- (NSURLSessionDataTask *)voteOnThingWithFullName:(NSString *)fullName direction:(RDKVoteDirection)direction completion:(RDKCompletionBlock)completion {
    NSString *dir;
    switch (direction) {
        case RDKVoteDirectionUp: dir = @"1"; break;
        case RDKVoteDirectionDown: dir = @"-1"; break;
        default: dir = @"0"; break;
    }
    return [self accountTaskWithPath:@"api/vote" parameters:@{@"id": fullName, @"dir": dir} completion:completion];
}

- (NSURLSessionDataTask *)upvote:(RDKVotable *)votable completion:(RDKCompletionBlock)completion {
    return [self voteOnThingWithFullName:votable.fullName ?: @"" direction:RDKVoteDirectionUp completion:completion];
}

- (NSURLSessionDataTask *)downvote:(RDKVotable *)votable completion:(RDKCompletionBlock)completion {
    return [self voteOnThingWithFullName:votable.fullName ?: @"" direction:RDKVoteDirectionDown completion:completion];
}

- (NSURLSessionDataTask *)revokeVote:(RDKVotable *)votable completion:(RDKCompletionBlock)completion {
    return [self voteOnThingWithFullName:votable.fullName ?: @"" direction:RDKVoteDirectionNone completion:completion];
}

- (NSURLSessionDataTask *)saveThingWithFullName:(NSString *)fullName completion:(RDKCompletionBlock)completion {
    return [self accountTaskWithPath:@"api/save" parameters:@{@"id": fullName} completion:completion];
}

- (NSURLSessionDataTask *)unsaveThingWithFullName:(NSString *)fullName completion:(RDKCompletionBlock)completion {
    return [self accountTaskWithPath:@"api/unsave" parameters:@{@"id": fullName} completion:completion];
}

// MARK: - User content

- (NSURLSessionDataTask *)subscribedSubredditsWithPagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    // The original formats this as "subreddits/mine/%@.json" with its
    // "subscriber" category
    return [self listingTaskWithPath:@"subreddits/mine/subscriber.json" parameters:nil pagination:pagination completion:completion];
}

- (NSURLSessionDataTask *)moderatedSubredditsWithPagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    return [self listingTaskWithPath:@"subreddits/mine/moderator.json" parameters:nil pagination:pagination completion:completion];
}

- (NSURLSessionDataTask *)inboxMessagesWithPagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    return [self listingTaskWithPath:@"messages/" parameters:nil pagination:pagination completion:completion];
}

- (NSURLSessionDataTask *)unreadInboxMessagesWithPagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    return [self listingTaskWithPath:@"messages/unread/" parameters:nil pagination:pagination completion:completion];
}

- (NSURLSessionDataTask *)savedLinksWithPagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    return [self listingTaskWithPath:@"user/me/saved/" parameters:nil pagination:pagination completion:completion];
}

// MARK: - Multireddits

- (NSURLSessionDataTask *)multiredditWithName:(NSString *)name completion:(RDKObjectCompletionBlock)completion {
    return [self getPath:[NSString stringWithFormat:@"api/multi/user/%@", name] parameters:nil completion:completion];
}

// api/multi/mine lists the account's multireddits, which RDKObjectBuilder maps
// to RDKMultireddit. Reddit has served this two ways over time: a Listing
// (data.children of "LabeledMulti" things) and, on some app types, a bare array
// of multi objects. Both are handled so an empty or array-shaped response isn't
// mistaken for a failure.
- (NSURLSessionDataTask *)multiredditsWithPagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    return [self getPath:@"api/multi/mine.json" parameters:nil completion:^(id response, NSError *error) {
        if (error) {
            completion(nil, nil, error);
            return;
        }

        NSMutableArray *objects = [NSMutableArray array];
        if ([response isKindOfClass:[NSDictionary class]]) {
            [objects addObjectsFromArray:[self objectsFromListingResponse:response]];
        } else if ([response isKindOfClass:[NSArray class]]) {
            for (id thing in response) {
                // A bare array holds the multi dicts directly; tolerate either the
                // wrapped or already-unwrapped shape
                NSDictionary *JSON = [thing isKindOfClass:[NSDictionary class]] ? thing : nil;
                if (JSON[@"data"]) {
                    id object = [[RDKObjectBuilder objectBuilder] objectFromJSON:JSON];
                    if (object) {
                        [objects addObject:object];
                    }
                }
            }
        } else {
            NSLog(@"[RDKClient] api/multi/mine returned an unexpected response (%@)", NSStringFromClass([response class]));
            completion(nil, nil, [self errorWithCode:RDKClientErrorInvalidResponse description:@"Expected a listing."]);
            return;
        }

        // Nothing paginates here in practice; keep the caller's preferences anyway
        RDKPagination *next = [RDKPagination paginationFromListingResponse:response];
        next.limit = pagination.limit;
        next.timeMethod = pagination.timeMethod;
        next.userContentSortingMethod = pagination.userContentSortingMethod;
        completion(objects, next, nil);
    }];
}

- (NSURLSessionDataTask *)linksInMultiredditWithName:(NSString *)name userName:(NSString *)userName category:(RDKSubredditCategory)category pagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    // The named form resolves to the same path api/multi/mine reports
    NSString *path = [NSString stringWithFormat:@"user/%@/m/%@", userName, name];
    return [self linksInMultiredditWithPath:path category:category pagination:pagination completion:completion];
}

// MARK: - Moderation

- (NSURLSessionDataTask *)moderationQueueForSubredditWithName:(NSString *)name pagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    return [self listingTaskWithPath:[NSString stringWithFormat:@"r/%@/about/modqueue", name] parameters:nil pagination:pagination completion:completion];
}

- (NSURLSessionDataTask *)moderationLogForSubredditWithName:(NSString *)name pagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    return [self listingTaskWithPath:[NSString stringWithFormat:@"r/%@/about/log", name] parameters:nil pagination:pagination completion:completion];
}

- (NSURLSessionDataTask *)approveLink:(RDKLink *)link completion:(RDKCompletionBlock)completion {
    return [self accountTaskWithPath:@"api/approve" parameters:@{@"id": link.fullName} completion:completion];
}

- (NSURLSessionDataTask *)approveComment:(RDKComment *)comment completion:(RDKCompletionBlock)completion {
    return [self accountTaskWithPath:@"api/approve" parameters:@{@"id": comment.fullName} completion:completion];
}

- (NSURLSessionDataTask *)removeLink:(RDKLink *)link spam:(BOOL)spam completion:(RDKCompletionBlock)completion {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObject:link.fullName forKey:@"id"];
    if (spam) {
        params[@"spam"] = @"";
    }
    return [self accountTaskWithPath:@"api/remove" parameters:params completion:completion];
}

- (NSURLSessionDataTask *)removeComment:(RDKComment *)comment spam:(BOOL)spam completion:(RDKCompletionBlock)completion {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObject:comment.fullName forKey:@"id"];
    if (spam) {
        params[@"spam"] = @"";
    }
    return [self accountTaskWithPath:@"api/remove" parameters:params completion:completion];
}

- (NSURLSessionDataTask *)lockLinkWithFullname:(NSString *)fullname completion:(RDKCompletionBlock)completion {
    return [self accountTaskWithPath:@"api/lock" parameters:@{@"id": fullname} completion:completion];
}

- (NSURLSessionDataTask *)lockComment:(RDKComment *)comment completion:(RDKCompletionBlock)completion {
    return [self accountTaskWithPath:@"api/lock" parameters:@{@"id": comment.fullName} completion:completion];
}

- (NSURLSessionDataTask *)distinguishComment:(RDKComment *)comment status:(NSInteger)status sticky:(BOOL)sticky completion:(RDKCompletionBlock)completion {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObject:comment.fullName forKey:@"id"];
    params[@"how"] = @(status) ? @"yes" : @"no";
    if (sticky) {
        params[@"sticky"] = @"true";
    }
    return [self accountTaskWithPath:@"api/distinguish" parameters:params completion:completion];
}

- (NSURLSessionDataTask *)distinguishThingWithFullName:(NSString *)name status:(NSInteger)status completion:(RDKCompletionBlock)completion {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObject:name forKey:@"id"];
    params[@"how"] = @(status) ? @"yes" : @"no";
    return [self accountTaskWithPath:@"api/distinguish" parameters:params completion:completion];
}

- (NSURLSessionDataTask *)setContestModeForLinkWithFullname:(NSString *)fullname contestMode:(BOOL)contestMode completion:(RDKCompletionBlock)completion {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObject:fullname forKey:@"id"];
    params[@"is_contest"] = contestMode ? @"true" : @"false";
    return [self accountTaskWithPath:@"api/contest" parameters:params completion:completion];
}

// MARK: - Modmail

- (NSURLSessionDataTask *)modmailConversationsWithPagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    return [self listingTaskWithPath:@"api/modmail/conversations" parameters:nil pagination:pagination completion:completion];
}

- (NSURLSessionDataTask *)searchModmailWithQuery:(NSString *)query limit:(NSInteger)limit completion:(RDKArrayCompletionBlock)completion {
    NSDictionary *params = @{@"q": query, @"limit": @(limit)};
    return [self getPath:@"api/modmail/conversations" parameters:params completion:^(id response, NSError *error) {
        if (response && [response isKindOfClass:[NSArray class]]) {
            completion(response, nil);
        } else {
            completion(nil, error);
        }
    }];
}

- (NSURLSessionDataTask *)createModmailThreadInSubreddit:(NSString *)subreddit subject:(NSString *)subject message:(NSString *)message completion:(RDKCompletionBlock)completion {
    NSDictionary *params = @{
        @"subreddit": subreddit,
        @"subject": subject,
        @"message": message
    };
    return [self accountTaskWithPath:@"api/modmail" parameters:params completion:completion];
}

// MARK: - Reporting

- (NSURLSessionDataTask *)createUserReportForThingWithFullname:(NSString *)fullname siteReason:(NSString *)reason completion:(RDKCompletionBlock)completion {
    NSDictionary *params = @{
        @"id": fullname,
        @"type": @"site",
        @"reason": reason
    };
    return [self accountTaskWithPath:@"api/report" parameters:params completion:completion];
}

- (NSURLSessionDataTask *)createUserReportForThingWithFullname:(NSString *)fullname subredditReason:(NSString *)reason completion:(RDKCompletionBlock)completion {
    NSDictionary *params = @{
        @"id": fullname,
        @"type": @"subreddit",
        @"reason": reason
    };
    return [self accountTaskWithPath:@"api/report" parameters:params completion:completion];
}

// MARK: - Search

- (NSURLSessionDataTask *)searchWithQuery:(NSString *)query sort:(NSString *)sort time:(NSString *)time subreddit:(NSString *)subreddit pagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObject:query forKey:@"q"];
    if (sort) {
        params[@"sort"] = sort;
    }
    if (time) {
        params[@"t"] = time;
    }
    NSString *path = subreddit ? [NSString stringWithFormat:@"r/%@/search", subreddit] : @"search";
    return [self listingTaskWithPath:path parameters:params pagination:pagination completion:completion];
}

- (NSURLSessionDataTask *)searchSubredditsWithQuery:(NSString *)query limit:(NSInteger)limit completion:(RDKArrayCompletionBlock)completion {
    NSDictionary *params = @{
        @"q": query,
        @"limit": @(limit),
        @"include_over_18": @"true"
    };
    return [self getPath:@"subreddits/search" parameters:params completion:^(id response, NSError *error) {
        if (response && [response isKindOfClass:[NSDictionary class]]) {
            NSDictionary *data = response[@"data"];
            NSArray *children = data[@"children"];
            RDKObjectBuilder *builder = [RDKObjectBuilder objectBuilder];
            NSMutableArray *subreddits = [NSMutableArray array];
            for (NSDictionary *child in children) {
                NSDictionary *subredditData = child[@"data"];
                id subreddit = [builder objectFromJSON:subredditData];
                if (subreddit) {
                    [subreddits addObject:subreddit];
                }
            }
            completion(subreddits, nil);
        } else {
            completion(nil, error);
        }
    }];
}

// MARK: - Convenience wrappers

- (NSURLSessionDataTask *)voteOnLink:(RDKLink *)link direction:(RDKVoteDirection)direction completion:(RDKCompletionBlock)completion {
    return [self voteOnThingWithFullName:link.fullName direction:direction completion:completion];
}

- (NSURLSessionDataTask *)saveLink:(RDKLink *)link completion:(RDKCompletionBlock)completion {
    return [self saveThingWithFullName:link.fullName completion:completion];
}

- (NSURLSessionDataTask *)hideLink:(RDKLink *)link completion:(RDKCompletionBlock)completion {
    return [self accountTaskWithPath:@"api/hide" parameters:@{@"id": link.fullName} completion:completion];
}

- (NSURLSessionDataTask *)userIconsForAccountFullNames:(NSArray<NSString *> *)fullNames
                                            completion:(void (^)(NSDictionary<NSString *, NSString *> *, NSError *))completion {
    if (fullNames.count == 0) {
        completion(@{}, nil);
        return nil;
    }
    NSString *ids = [fullNames componentsJoinedByString:@","];
    return [self getPath:@"api/user_data_by_account_ids.json" parameters:@{@"ids": ids} completion:^(id response, NSError *error) {
        if (error != nil || ![response isKindOfClass:[NSDictionary class]]) {
            completion(nil, error);
            return;
        }
        NSMutableDictionary<NSString *, NSString *> *icons = [NSMutableDictionary dictionary];
        [(NSDictionary *)response enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            if (![key isKindOfClass:[NSString class]] || ![value isKindOfClass:[NSDictionary class]]) {
                return;
            }
            // This endpoint answers with `profile_img` (a snoovatar headshot), not
            // the `icon_img` the subreddit endpoint uses.
            NSString *iconURL = value[@"profile_img"];
            if ([iconURL isKindOfClass:[NSString class]] && iconURL.length > 0) {
                icons[key] = iconURL;
            }
        }];
        completion(icons, nil);
    }];
}

- (NSURLSessionDataTask *)commentsInSubredditWithName:(NSString *)name category:(RDKSubredditCategory)category pagination:(RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion {
    NSString *path = [NSString stringWithFormat:@"r/%@/comments/%@.json", name, RDKStringFromSubredditCategory(category)];
    return [self listingTaskWithPath:path parameters:nil pagination:pagination completion:completion];
}

@end
