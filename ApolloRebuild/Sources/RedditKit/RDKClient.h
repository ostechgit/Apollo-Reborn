#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>
#import "RDKOAuthCredential.h"
#import "RDKPagination.h"
#import "RDKLink.h"
#import "RDKComment.h"
#import "RDKMoreComments.h"

// RDKClient - the Reddit API client (Apollo's RedditKit fork)
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// An AFHTTPSessionManager like the original. Requests go to https://oauth.reddit.com
// with a bearer token: the signed-in account's, or an app-only token (Reddit's
// installed_client grant) for logged-out browsing. Expired tokens are refreshed
// before a request goes out; requests made meanwhile wait, and a 401 triggers one
// refresh-and-retry. Like the original, every request carries raw_json=1 (GET) or
// api_type=json (POST). The original also reported rate-limit usage to
// apolloreq.com, Apollo's own (now defunct) server; that is not reproduced.
//
// The original exposes ~450 endpoints; this covers auth, listings, comments,
// voting and saving. Completion blocks run on the main queue.

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const RDKClientErrorDomain;

typedef NS_ERROR_ENUM(RDKClientErrorDomain, RDKClientErrorCode) {
    RDKClientErrorAuthenticationRequired = 1,  // no client ID configured, or no signed-in account for an account-only call
    RDKClientErrorInvalidOAuthGrant = 2,       // Reddit rejected the code / refresh token
    RDKClientErrorInvalidResponse = 3,         // unexpected JSON shape
    RDKClientErrorPermissionDenied = 403,
    RDKClientErrorNotFound = 404,
    RDKClientErrorRateLimited = 429,
    RDKClientErrorServer = 500,
};

// Posted (main queue) when the signed-in state or token changes; persist the client then
FOUNDATION_EXPORT NSNotificationName const RDKClientAuthorizationDidChangeNotification;

typedef void (^RDKCompletionBlock)(NSError *_Nullable error);
typedef void (^RDKObjectCompletionBlock)(id _Nullable object, NSError *_Nullable error);
typedef void (^RDKArrayCompletionBlock)(NSArray *_Nullable collection, NSError *_Nullable error);
typedef void (^RDKListingCompletionBlock)(NSArray *_Nullable collection, RDKPagination *_Nullable pagination, NSError *_Nullable error);
typedef void (^RDKLinkAndCommentsCompletionBlock)(RDKLink *_Nullable link, NSArray<RDKThing *> *_Nullable comments, NSError *_Nullable error);

@interface RDKClient : AFHTTPSessionManager <NSSecureCoding>

+ (instancetype)sharedClient;
+ (NSURL *)APIBaseURL;       // https://www.reddit.com/ (token endpoints)
+ (NSURL *)APIBaseOAuthURL;  // https://oauth.reddit.com/ (API)
+ (NSArray<NSString *> *)allScopes;

// MARK: Configuration and state

@property (nonatomic, strong, nullable) RDKOAuthCredential *authorizationCredential;
@property (nonatomic, copy, nullable) NSString *clientSecret;  // empty for "installed app" keys
@property (nonatomic, assign) BOOL usesApplicationOnlyOAuth;   // current token is app-only (logged out)
@property (nonatomic, copy) NSString *userAgent;                // sent on every Reddit request, token requests included
@property (nonatomic, assign) BOOL refreshingToken;
@property (nonatomic, assign) unsigned long long rateLimitedRequestsRemaining;
@property (nonatomic, assign) unsigned long long rateLimitedRequestsUsed;
@property (nonatomic, assign) double timeUntilRateLimitReset;

// Sets the Reddit app to authenticate with. Changing the client ID drops the current token.
- (void)authenticateWithClientIdentifier:(NSString *)clientIdentifier redirectURI:(nullable NSURL *)redirectURI;

@property (nonatomic, readonly) BOOL hasClientIdentifier;
@property (nonatomic, readonly) BOOL isAuthenticated;          // has any token (account or app-only)
@property (nonatomic, readonly) BOOL isAuthenticatedWithOAuth; // signed in to an account

// MARK: Signing in

// Reddit's consent page; the redirect carries ?state=...&code=...
- (nullable NSURL *)authorizationURLWithState:(NSString *)state;

// Trades the code from the redirect for the account's tokens
- (nullable NSURLSessionDataTask *)signInWithAuthorizationCode:(NSString *)code completion:(RDKCompletionBlock)completion;

// Gets an app-only token for logged-out browsing (done automatically when needed)
- (nullable NSURLSessionDataTask *)authenticateApplicationOnlyWithCompletion:(RDKCompletionBlock)completion;

// Revokes the account's refresh token (best effort) and forgets it
- (void)signOutWithCompletion:(nullable RDKCompletionBlock)completion;

// The signed-in account (/api/v1/me) as its JSON dictionary
- (nullable NSURLSessionDataTask *)currentUserWithCompletion:(RDKObjectCompletionBlock)completion;

// MARK: Listings

- (nullable NSURLSessionDataTask *)frontPageLinksWithCategory:(RDKSubredditCategory)category pagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)linksInAllSubredditsWithCategory:(RDKSubredditCategory)category pagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)linksInSubredditWithName:(NSString *)subredditName category:(RDKSubredditCategory)category pagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion NS_SWIFT_NAME(links(inSubredditWithName:category:pagination:completion:));
- (nullable NSURLSessionDataTask *)linksInMultiredditWithPath:(NSString *)path category:(RDKSubredditCategory)category pagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion NS_SWIFT_NAME(links(inMultiredditPath:category:pagination:completion:));
- (nullable NSURLSessionDataTask *)submittedLinksByUserWithUsername:(NSString *)username pagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion;

// MARK: Comments

- (nullable NSURLSessionDataTask *)commentsForLinkWithIdentifier:(NSString *)identifier sort:(RDKCommentSortingMethod)sort limit:(NSInteger)limit completion:(RDKArrayCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)linkAndCommentsForLinkWithIdentifier:(NSString *)identifier commentSort:(RDKCommentSortingMethod)sort pagination:(nullable RDKPagination *)pagination completion:(RDKLinkAndCommentsCompletionBlock)completion NS_SWIFT_NAME(linkAndComments(forLinkWithIdentifier:commentSort:pagination:completion:));
// Expands a "load more comments" stub (api/morechildren); returns the comments as a flat list
- (nullable NSURLSessionDataTask *)moreComments:(RDKMoreComments *)moreComments forLink:(RDKLink *)link sort:(RDKCommentSortingMethod)sort completion:(RDKArrayCompletionBlock)completion;

// MARK: Voting and saving (account required)

- (nullable NSURLSessionDataTask *)voteOnThingWithFullName:(NSString *)fullName direction:(RDKVoteDirection)direction completion:(RDKCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)upvote:(RDKVotable *)votable completion:(RDKCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)downvote:(RDKVotable *)votable completion:(RDKCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)revokeVote:(RDKVotable *)votable completion:(RDKCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)saveThingWithFullName:(NSString *)fullName completion:(RDKCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)unsaveThingWithFullName:(NSString *)fullName completion:(RDKCompletionBlock)completion;

// MARK: User content (account required)

- (nullable NSURLSessionDataTask *)subscribedSubredditsWithPagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion NS_SWIFT_NAME(subscribedSubreddits(pagination:completion:));
// subreddits/mine/moderator — the subreddits the account moderates
- (nullable NSURLSessionDataTask *)moderatedSubredditsWithPagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion NS_SWIFT_NAME(moderatedSubreddits(pagination:completion:));
- (nullable NSURLSessionDataTask *)inboxMessagesWithPagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion NS_SWIFT_NAME(inboxMessages(pagination:completion:));
- (nullable NSURLSessionDataTask *)unreadInboxMessagesWithPagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion NS_SWIFT_NAME(unreadInboxMessages(pagination:completion:));
- (nullable NSURLSessionDataTask *)savedLinksWithPagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion NS_SWIFT_NAME(savedLinks(pagination:completion:));

// MARK: Multireddits (account required)

- (nullable NSURLSessionDataTask *)multiredditWithName:(NSString *)name completion:(RDKObjectCompletionBlock)completion;
// api/multi/mine.json — every multireddit the account owns, newest Reddit shape
- (nullable NSURLSessionDataTask *)multiredditsWithPagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion NS_SWIFT_NAME(multireddits(pagination:completion:));
// The original's name-based convenience: user/<userName>/m/<name> is the path
// Reddit serves a multireddit's listing from
- (nullable NSURLSessionDataTask *)linksInMultiredditWithName:(NSString *)name userName:(NSString *)userName category:(RDKSubredditCategory)category pagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion NS_SWIFT_NAME(links(inMultireddit:userName:category:pagination:completion:));

// MARK: Moderation (moderator required)

- (nullable NSURLSessionDataTask *)moderationQueueForSubredditWithName:(NSString *)name pagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)moderationLogForSubredditWithName:(NSString *)name pagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)approveLink:(RDKLink *)link completion:(RDKCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)approveComment:(RDKComment *)comment completion:(RDKCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)removeLink:(RDKLink *)link spam:(BOOL)spam completion:(RDKCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)removeComment:(RDKComment *)comment spam:(BOOL)spam completion:(RDKCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)lockLinkWithFullname:(NSString *)fullname completion:(RDKCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)lockComment:(RDKComment *)comment completion:(RDKCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)distinguishComment:(RDKComment *)comment status:(NSInteger)status sticky:(BOOL)sticky completion:(RDKCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)distinguishThingWithFullName:(NSString *)name status:(NSInteger)status completion:(RDKCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)setContestModeForLinkWithFullname:(NSString *)fullname contestMode:(BOOL)contestMode completion:(RDKCompletionBlock)completion;

// MARK: Modmail (moderator required)

- (nullable NSURLSessionDataTask *)modmailConversationsWithPagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion NS_SWIFT_NAME(modmailConversations(pagination:completion:));
- (nullable NSURLSessionDataTask *)searchModmailWithQuery:(NSString *)query limit:(NSInteger)limit completion:(RDKArrayCompletionBlock)completion NS_SWIFT_NAME(searchModmail(query:limit:completion:));
- (nullable NSURLSessionDataTask *)createModmailThreadInSubreddit:(NSString *)subreddit subject:(NSString *)subject message:(NSString *)message completion:(RDKCompletionBlock)completion NS_SWIFT_NAME(createModmailThread(subreddit:subject:message:completion:));

// MARK: Reporting

- (nullable NSURLSessionDataTask *)createUserReportForThingWithFullname:(NSString *)fullname siteReason:(NSString *)reason completion:(RDKCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)createUserReportForThingWithFullname:(NSString *)fullname subredditReason:(NSString *)reason completion:(RDKCompletionBlock)completion;

// MARK: Search

- (nullable NSURLSessionDataTask *)searchWithQuery:(NSString *)query sort:(NSString *)sort time:(nullable NSString *)time subreddit:(nullable NSString *)subreddit pagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion NS_SWIFT_NAME(search(query:sort:time:subreddit:pagination:completion:));
- (nullable NSURLSessionDataTask *)searchSubredditsWithQuery:(NSString *)query limit:(NSInteger)limit completion:(RDKArrayCompletionBlock)completion NS_SWIFT_NAME(searchSubreddits(query:limit:completion:));

// MARK: Convenience wrappers

- (nullable NSURLSessionDataTask *)voteOnLink:(RDKLink *)link direction:(RDKVoteDirection)direction completion:(RDKCompletionBlock)completion NS_SWIFT_NAME(voteOnLink(_:direction:completion:));
- (nullable NSURLSessionDataTask *)saveLink:(RDKLink *)link completion:(RDKCompletionBlock)completion NS_SWIFT_NAME(saveLink(_:completion:));
- (nullable NSURLSessionDataTask *)hideLink:(RDKLink *)link completion:(RDKCompletionBlock)completion NS_SWIFT_NAME(hideLink(_:completion:));
- (nullable NSURLSessionDataTask *)commentsInSubredditWithName:(NSString *)name category:(RDKSubredditCategory)category pagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion;

// MARK: Generic requests (paths are relative to APIBaseOAuthURL)

- (nullable NSURLSessionDataTask *)getPath:(NSString *)path parameters:(nullable NSDictionary *)parameters completion:(RDKObjectCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)postPath:(NSString *)path parameters:(nullable NSDictionary *)parameters completion:(RDKObjectCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)taskWithMethod:(NSString *)method path:(NSString *)path parameters:(nullable NSDictionary *)parameters completion:(RDKObjectCompletionBlock)completion;
- (nullable NSURLSessionDataTask *)listingTaskWithPath:(NSString *)path parameters:(nullable NSDictionary *)parameters pagination:(nullable RDKPagination *)pagination completion:(RDKListingCompletionBlock)completion;

// Model objects from a Listing response
- (NSArray *)objectsFromListingResponse:(nullable NSDictionary *)response;

@end

NS_ASSUME_NONNULL_END
