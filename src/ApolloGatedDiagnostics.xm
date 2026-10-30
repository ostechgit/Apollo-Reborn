// ApolloGatedDiagnostics - temporary runtime probes for the rebuild.
//
// These hooks exist only to OBSERVE what stock Apollo does, so the rebuild can be
// written against real behaviour instead of inference. They never change
// behaviour: every probe is gated behind the APOLLO_DIAG_PROBE environment
// variable (set via SIMCTL_CHILD_APOLLO_DIAG_PROBE=1) and only writes to the
// os_log stream (`subsystem == "apollofix"`).
//
// Findings to capture:
//   G1  swipe actions on the comments list (which selectors exist, what the
//       delegate returns)
//   G6  the exact `api/report` payload stock sends, including reason literals
//   G4  whether the BASE comment cell draws an avatar (tweak-injected nodes are
//       reported separately so they cannot be mistaken for stock behaviour)
//   G3  what "Share as Image" hands to the share sheet
//
// Delete this file (and its Makefile entry) once the evidence is recorded.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "ApolloCommon.h"

// When set, write-style probes log the arguments and then abort the call, so a
// real report is never filed while the literals are being recorded.
static BOOL ApolloDiagBlockWrites(void) {
    static BOOL block;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        block = [NSProcessInfo.processInfo.environment[@"APOLLO_DIAG_BLOCK_WRITES"] boolValue];
    });
    return block;
}

static BOOL ApolloDiagProbeEnabled(void) {
    static BOOL enabled;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        enabled = [NSProcessInfo.processInfo.environment[@"APOLLO_DIAG_PROBE"] boolValue];
    });
    return enabled;
}

// A class whose image is the tweak's own is NOT stock behaviour.
static BOOL ApolloDiagClassIsTweakOwned(Class cls) {
    if (!cls) return NO;
    NSString *path = [NSBundle bundleForClass:cls].bundlePath ?: @"";
    return [path containsString:@"ApolloReborn"] || [path containsString:@"apollofix"];
}

%group ApolloDiag

// MARK: - G1: which swipe selectors does the comments screen actually have?

%hook _TtC6Apollo22CommentsViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!ApolloDiagProbeEnabled()) return;

    UIViewController *vc = (UIViewController *)self;
    Class cls = object_getClass(self);
    NSArray<NSString *> *needles = @[@"Swipe", @"swipe", @"Preview", @"preview"];
    NSMutableArray<NSString *> *own = [NSMutableArray array];
    NSMutableArray<NSString *> *inherited = [NSMutableArray array];

    for (Class walk = cls; walk && walk != [NSObject class]; walk = class_getSuperclass(walk)) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(walk, &count);
        for (unsigned int i = 0; i < count; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            for (NSString *needle in needles) {
                if ([name containsString:needle]) {
                    NSMutableArray<NSString *> *bucket = (walk == cls) ? own : inherited;
                    [bucket addObject:name];
                    break;
                }
            }
        }
        free(methods);
    }

    id<UITableViewDelegate> delegate = nil;
    if ([vc isKindOfClass:[UITableViewController class]]) {
        delegate = ((UITableViewController *)vc).tableView.delegate;
    }
    NSMutableArray<NSString *> *delegateSwipes = [NSMutableArray array];
    for (NSString *selector in @[@"tableView:leadingSwipeActionsConfigurationForRowAtIndexPath:",
                                 @"tableView:trailingSwipeActionsConfigurationForRowAtIndexPath:"]) {
        if ([delegate respondsToSelector:NSSelectorFromString(selector)]) {
            [delegateSwipes addObject:selector];
        }
    }

    ApolloLog(@"[diag G1] delegate=%@ delegateSwipes=[%@]", NSStringFromClass([delegate class]),
              [delegateSwipes componentsJoinedByString:@","]);
    ApolloLog(@"[diag G1] own=[%@]", [own componentsJoinedByString:@" | "]);
    ApolloLog(@"[diag G1] inherited=[%@]", [inherited componentsJoinedByString:@" | "]);
}

%end

// MARK: - G6: what does stock actually send to api/report?

%hook RDKClient

- (id)createUserReportForThingWithFullname:(id)fullname
                                siteReason:(id)siteReason
                              customReason:(id)customReason
                                completion:(id)completion {
    if (ApolloDiagProbeEnabled()) {
        ApolloLog(@"[diag G6] siteReason=%@ customReason=%@ thing=%@", siteReason, customReason, fullname);
    }
    return %orig;
}

- (id)createUserReportForThingWithFullname:(id)fullname
                              customReason:(id)customReason
                                completion:(id)completion {
    if (ApolloDiagProbeEnabled()) {
        ApolloLog(@"[diag G6] custom-only custom=%@ thing=%@", customReason, fullname);
    }
    return %orig;
}

- (id)createUserReportForThingWithFullname:(id)fullname
                          subredditReason:(id)reason
                                completion:(id)completion {
    if (ApolloDiagProbeEnabled()) {
        ApolloLog(@"[diag G6] subredditReason=%@ thing=%@", reason, fullname);
    }
    return %orig;
}

%end

// The authoritative record is the request body itself.
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    if (ApolloDiagProbeEnabled()) {
        NSString *path = request.URL.path ?: @"";
        if ([path containsString:@"report"] || [path containsString:@"rule"] ||
            [path containsString:@"award"] || [path containsString:@"remind"]) {
            NSString *body = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
            ApolloLog(@"[diag G6] %@ %@ body=%@", request.HTTPMethod, path, body);
        }
    }
    return %orig;
}

%end

// One funnel for every write: the base posts through
// -[RDKClient basicPostTaskWithPath:parameters:completion:] (0x100006cf0), so
// logging here captures report, award and reminder payloads alike. With
// APOLLO_DIAG_BLOCK_WRITES=1 the request is aborted after logging.
%hook RDKClient

- (id)basicPostTaskWithPath:(id)path parameters:(id)parameters completion:(id)completion {
    if (ApolloDiagProbeEnabled()) {
        NSString *redacted = [parameters description];
        SEL redact = NSSelectorFromString(@"apollo_redactedDescription");
        if ([parameters respondsToSelector:redact]) {
            redacted = ((id (*)(id, SEL))objc_msgSend)(parameters, redact);
        }
        ApolloLog(@"[diag POST] %@ params=%@ blocked=%d", path, redacted, ApolloDiagBlockWrites());
        if (ApolloDiagBlockWrites()) return nil;
    }
    return %orig;
}

%end

// MARK: - G3: what goes into the share sheet?

%hook UIActivityViewController

- (instancetype)initWithActivityItems:(NSArray *)items applicationActivities:(NSArray *)activities {
    id result = %orig;
    if (ApolloDiagProbeEnabled()) {
        NSMutableArray<NSString *> *described = [NSMutableArray array];
        for (id item in items) {
            if ([item isKindOfClass:[UIImage class]]) {
                CGSize size = ((UIImage *)item).size;
                [described addObject:[NSString stringWithFormat:@"UIImage %.0fx%.0f", size.width, size.height]];
            } else if ([item isKindOfClass:[NSURL class]]) {
                [described addObject:[NSString stringWithFormat:@"NSURL(.%@)", ((NSURL *)item).pathExtension ?: @"none"]];
            } else {
                [described addObject:NSStringFromClass([item class])];
            }
        }
        ApolloLog(@"[diag G3] share items=[%@]", [described componentsJoinedByString:@" | "]);
    }
    return result;
}

%end

// MARK: - G4: does the BASE comment cell draw an avatar?

%hook _TtC6Apollo15CommentCellNode

- (void)didLoad {
    %orig;
    if (!ApolloDiagProbeEnabled()) return;

    NSMutableArray<NSString *> *stock = [NSMutableArray array];
    NSMutableArray<NSString *> *tweak = [NSMutableArray array];
    id cell = (id)self;
    SEL subnodesSelector = NSSelectorFromString(@"subnodes");
    NSArray *subnodes = [(NSObject *)cell respondsToSelector:subnodesSelector]
        ? ((NSArray *(*)(id, SEL))objc_msgSend)(cell, subnodesSelector)
        : @[];
    for (id node in subnodes) {
        NSString *name = NSStringFromClass([node class]);
        NSMutableArray<NSString *> *bucket = ApolloDiagClassIsTweakOwned([node class]) ? tweak : stock;
        [bucket addObject:name];
    }
    ApolloLog(@"[diag G4] comment stockNodes=[%@] tweakNodes=[%@]",
              [stock componentsJoinedByString:@","], [tweak componentsJoinedByString:@","]);
}

%end

%end  // ApolloDiag

%ctor {
    if (ApolloDiagProbeEnabled()) {
        %init(ApolloDiag);
        ApolloLog(@"[diag] gated diagnostics armed");
    }
}
