#import <Foundation/Foundation.h>
#import "RDKClient.h"

static int checks, failures;
#define CHECK(condition) do { checks++; if (!(condition)) { failures++; NSLog(@"FAIL line %d: %s", __LINE__, #condition); } } while (0)

// Exercise real request construction and response serialization, replacing only
// the final network boundary. Returning nil makes the production resume a no-op.
@interface StubClient : RDKClient
@property NSInteger sends;
@property NSInteger status;
@property id payload;
@property NSError *networkError;
@property NSURLRequest *capturedRequest;
@end
@implementation StubClient
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                             uploadProgress:(void (^)(NSProgress *))uploadProgress
                           downloadProgress:(void (^)(NSProgress *))downloadProgress
                          completionHandler:(void (^)(NSURLResponse *, id, NSError *))completion {
    self.sends++;
    self.capturedRequest = request;
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:self.status HTTPVersion:@"HTTP/1.1" headerFields:@{}];
    NSError *error = self.networkError;
    NSData *data = self.payload ? [NSJSONSerialization dataWithJSONObject:self.payload options:NSJSONWritingFragmentsAllowed error:nil] : [@"not JSON" dataUsingEncoding:NSUTF8StringEncoding];
    id object = error ? nil : [self.responseSerializer responseObjectForResponse:response data:data error:&error];
    completion(response, object, error);
    return nil;
}
@end

static StubClient *Client(void) {
    StubClient *client = [StubClient new];
    RDKOAuthCredential *credential = [RDKOAuthCredential new];
    credential.clientIdentifier = @"local-test-only";
    credential.accessToken = [RDKAccessToken new];
    credential.accessToken.accessToken = @"not-a-real-token";
    credential.accessToken.refreshToken = @"not-a-real-refresh-token";
    credential.accessToken.expirationDate = [NSDate distantFuture];
    client.authorizationCredential = credential;
    client.status = 200;
    return client;
}
static NSDictionary *Result(NSString *kind, NSDictionary *fields) {
    return @{@"json": @{@"errors": @[], @"data": @{@"things": @[@{@"kind": kind, @"data": fields}]}}};
}
static NSDictionary *Fields(NSString *parent) {
    return @{@"id": @"reply", @"name": @"t1_reply", @"parent_id": parent,
             @"body": @"Unicode — café\nreply", @"author": @"local", @"replies": @""};
}
static void Submit(StubClient *client, NSString *target, BOOL success) {
    __block NSInteger completions = 0;
    [client submitComment:@"Unicode — café\nreply" onThingWithFullName:target completion:^(RDKComment *comment, NSError *error) {
        completions++;
        CHECK((comment != nil) == success);
        CHECK((error == nil) == success);
        if (success) { CHECK([comment.parentID isEqual:target]); CHECK([comment.fullName isEqual:@"t1_reply"]); }
    }];
    CHECK(completions == 1);
}
int main(void) { @autoreleasepool {
    for (NSString *target in @[@"t3_post", @"t1_parent"]) {
        StubClient *client = Client(); client.payload = Result(@"t1", Fields(target));
        Submit(client, target, YES);
        CHECK(client.sends == 1);
        CHECK([client.capturedRequest.HTTPMethod isEqual:@"POST"]);
        CHECK([client.capturedRequest.URL.path isEqual:@"/api/comment"]);
        NSString *body = [[NSString alloc] initWithData:client.capturedRequest.HTTPBody encoding:NSUTF8StringEncoding];
        CHECK([body containsString:@"api_type=json"]);
        CHECK([body containsString:[@"thing_id=" stringByAppendingString:target]]);
        CHECK([body containsString:@"text=Unicode"]);
        NSURLComponents *form = [NSURLComponents new]; form.percentEncodedQuery = body;
        NSMutableDictionary *values = [NSMutableDictionary dictionary];
        for (NSURLQueryItem *item in form.queryItems) { values[item.name] = item.value; }
        CHECK([values[@"text"] isEqual:@"Unicode — café\nreply"]);
    }
    NSArray *invalid = @[
        @{}, @{@"json": [NSNull null]}, @{@"json": @42}, @{@"json": @"bad"},
        @{@"json": @{@"data": @{}}},
        Result(@"t1", Fields(@"t1_wrong")), Result(@"t3", Fields(@"t3_post")),
        Result(@"t1", @{@"name": @"t1_reply", @"parent_id": @"t3_post"}),
        Result(@"t1", @{@"id": @"reply", @"name": @"t1_other", @"parent_id": @"t3_post"}),
        @{@"json": @{@"errors": @[@[@"RATELIMIT", @"Mock rate limit", @"text"]]}}
    ];
    for (id payload in invalid) {
        StubClient *client = Client(); client.payload = payload;
        Submit(client, @"t3_post", NO); CHECK(client.sends == 1);
    }
    for (NSNumber *status in @[@401, @403, @500]) {
        StubClient *client = Client(); client.status = status.integerValue;
        client.payload = @{@"message": @"Denied"};
        Submit(client, @"t3_post", NO); CHECK(client.sends == 1);
    }
    StubClient *network = Client();
    network.networkError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    Submit(network, @"t3_post", NO); CHECK(network.sends == 1);
    StubClient *malformed = Client(); Submit(malformed, @"t3_post", NO); CHECK(malformed.sends == 1);
    StubClient *appOnly = Client(); appOnly.usesApplicationOnlyOAuth = YES;
    Submit(appOnly, @"t3_post", NO); CHECK(appOnly.sends == 0);
    StubClient *loggedOut = Client(); loggedOut.authorizationCredential = nil;
    Submit(loggedOut, @"t3_post", NO); CHECK(loggedOut.sends == 0);
    StubClient *badTarget = Client(); Submit(badTarget, @"invalid", NO); CHECK(badTarget.sends == 0);
    StubClient *empty = Client();
    [empty submitComment:@" \n" onThingWithFullName:@"t3_post" completion:^(RDKComment *comment, NSError *error) { CHECK(!comment && error); }];
    CHECK(empty.sends == 0);
    printf("%d checks, %d failures (actual client; no network)\n", checks, failures);
    return failures ? 1 : 0;
} }
