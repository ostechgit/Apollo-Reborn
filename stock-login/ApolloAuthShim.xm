// ApolloAuthShim - the minimum of Apollo-Reborn needed to log in.
//
// Stock Apollo 1.15.11 ships its own embedded Reddit OAuth client id, which
// Reddit revoked, and it has no UI for entering a replacement. This dylib
// supplies one so *stock* Apollo can be run in the simulator for evidence:
// the point is to observe unmodified Apollo, so the shim deliberately contains
// only the credential plumbing and nothing that touches layout, features or
// image handling.
//
// Hooks, all lifted in behaviour from the Reborn tweak's auth layer
// (src/Tweak.xm), minus everything else:
//
//   1. -[RDKOAuthCredential clientIdentifier] / -redirectURI
//        Apollo builds its OAuth credential from its own constants; substitute
//        the user-supplied client id and redirect URI.
//   2. -[AFHTTPRequestSerializer setAuthorizationHeaderFieldWithUsername:password:]
//        Reddit's token endpoint is called with HTTP Basic auth and an EMPTY
//        password. That is correct for a public/installed-app client, but a
//        confidential ("web app") client must send its client_secret, otherwise
//        every token request 401s. Hooking this one low-level call covers the
//        authorization_code exchange, refresh_token grant and the
//        application-only token in one place.
//   3. -[RDKClient userAgent]
//        Reddit rejects Apollo's default UA once its client id is replaced, so
//        the user-supplied UA is returned when one is configured.
//
// Credentials come from the same NSUserDefaults keys the Reborn tweak uses, so
// a Reborn settings backup can be preloaded unchanged:
//
//   RedditApiClientId, RedditApiClientSecret, RedirectURI, UserAgent
//
// Values are read on each call rather than cached, so editing the plist or
// restoring a backup takes effect without a relaunch.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Minimal declarations: this target does not import the repo's Headers/ tree.
@interface RDKOAuthCredential : NSObject
- (NSString *)clientIdentifier;
- (NSURL *)redirectURI;
@end

@interface AFHTTPRequestSerializer : NSObject
- (void)setAuthorizationHeaderFieldWithUsername:(NSString *)username password:(NSString *)password;
@end

@interface RDKClient : NSObject
- (NSString *)userAgent;
@end

static NSString *const kKeyClientId = @"RedditApiClientId";
static NSString *const kKeyClientSecret = @"RedditApiClientSecret";
static NSString *const kKeyRedirectURI = @"RedirectURI";
static NSString *const kKeyUserAgent = @"UserAgent";

static NSString *ApolloAuthString(NSString *key) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

static void ApolloAuthLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[StockLogin] %@", message);
}

// Seed the credential keys from a plist dropped in Library/Caches by install.sh.
//
// This exists because writing the app's Preferences plist directly does not take
// effect: cfprefsd owns the domain and ignores out-of-band file edits, and the
// simulator's `defaults` tool cannot see an app's sandbox domain either. Letting
// the app write its own defaults through NSUserDefaults is the only reliable way
// to preload credentials without a Settings UI.
static void ApolloAuthSeedFromFile(void) {
    NSString *seedPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/StockLogin.plist"];
    NSDictionary *seed = [NSDictionary dictionaryWithContentsOfFile:seedPath];
    if (![seed isKindOfClass:[NSDictionary class]]) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray<NSString *> *keys = @[kKeyClientId, kKeyClientSecret, kKeyRedirectURI, kKeyUserAgent];
    BOOL changed = NO;
    for (NSString *key in keys) {
        id value = seed[key];
        if ([value isKindOfClass:[NSString class]] && [value length] > 0
            && [[defaults objectForKey:key] isKindOfClass:[NSString class]] == NO) {
            [defaults setObject:value forKey:key];
            changed = YES;
        }
    }
    if (changed) {
        [defaults synchronize];
        ApolloAuthLog(@"seeded credentials from %@", [seedPath lastPathComponent]);
    }
}

%hook RDKOAuthCredential

- (NSString *)clientIdentifier {
    NSString *configured = ApolloAuthString(kKeyClientId);
    return configured.length > 0 ? configured : %orig;
}

- (NSURL *)redirectURI {
    NSString *configured = ApolloAuthString(kKeyRedirectURI);
    return configured.length > 0 ? [NSURL URLWithString:configured] : %orig;
}

%end

%hook AFHTTPRequestSerializer

- (void)setAuthorizationHeaderFieldWithUsername:(NSString *)username password:(NSString *)password {
    if (password.length == 0) {
        NSString *secret = ApolloAuthString(kKeyClientSecret);
        if (secret.length > 0) {
            %orig(username, secret);
            return;
        }
    }
    %orig;
}

%end

%hook RDKClient

- (NSString *)userAgent {
    NSString *configured = ApolloAuthString(kKeyUserAgent);
    return configured.length > 0 ? configured : %orig;
}

%end

%ctor {
    ApolloAuthSeedFromFile();
    NSString *clientId = ApolloAuthString(kKeyClientId);
    NSString *secret = ApolloAuthString(kKeyClientSecret);
    NSString *redirect = ApolloAuthString(kKeyRedirectURI);
    ApolloAuthLog(@"auth shim loaded (client id %@, secret %@, redirect %@)",
                  clientId.length > 0 ? @"set" : @"MISSING",
                  secret.length > 0 ? @"set" : @"MISSING",
                  redirect.length > 0 ? @"set" : @"MISSING");
}
