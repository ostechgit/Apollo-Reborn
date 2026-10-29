#import "RDKClient.h"
#import "RDKObjectBuilder.h"
#import "RDKResponseSerializer.h"

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
        completion([link isKindOfClass:[RDKLink class]] ? link : nil, comments, nil);
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

@end
