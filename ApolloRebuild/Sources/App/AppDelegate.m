#import "AppDelegate.h"
#import <UserNotifications/UserNotifications.h>

// Apollo AppDelegate
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Methods recovered:
//   - init
//   - application:didFinishLaunchingWithOptions:
//   - applicationDidEnterBackground:
//   - applicationWillEnterForeground:
//   - applicationWillTerminate:
//   - application:openURL:options:
//   - ubiquitousKeyValueStoreDidChangeExternallyWithNotification:
//   - application:supportedInterfaceOrientationsForWindow:
//   - application:didRegisterForRemoteNotificationsWithDeviceToken:
//   - application:didFailToRegisterForRemoteNotificationsWithError:
//   - userNotificationCenter:willPresentNotification:withCompletionHandler:
//   - userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:
//   - userNotificationCenter:openSettingsForNotification:
//   - productsRequest:didReceiveResponse:
//   - .cxx_destruct (ARC cleanup)
//
// The original app uses Mixpanel for analytics, Statsig for feature flags,
// SwiftyStoreKit for In-App Purchases, and various other services.

@implementation AppDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize app state
        NSLog(@"[Apollo] AppDelegate initialized");
    }
    return self;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"[Apollo] Application did finish launching");
    
    // Set up the main window
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    
    // Set up the root view controller
    // In the original app, this would be the ApolloTabBarController
    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = rootVC;
    
    [self.window makeKeyAndVisible];
    
    // Register for remote notifications
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert)
                                  completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted) {
                [[UIApplication sharedApplication] registerForRemoteNotifications];
            }
        }];
    }
    
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    NSLog(@"[Apollo] Application entered background");
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    NSLog(@"[Apollo] Application will enter foreground");
}

- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"[Apollo] Application will terminate");
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    NSLog(@"[Apollo] Application opened URL: %@", url);
    return YES;
}

@end