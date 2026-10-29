#import "RDKObjectBuilder.h"
#import <Mantle/Mantle.h>
#import "RDKComment.h"
#import "RDKLink.h"
#import "RDKMoreComments.h"
#import "RDKUser.h"
#import "RDKMessage.h"
#import "RDKCommentReplyMessage.h"
#import "RDKSubreddit.h"
#import "RDKMultireddit.h"

// RDKObjectBuilder - turns Reddit JSON "things" into model objects
// Reconstructed from apollo-base 1.15.11 binary analysis.

@implementation RDKObjectBuilder

+ (instancetype)objectBuilder {
    static RDKObjectBuilder *builder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        builder = [[RDKObjectBuilder alloc] init];
    });
    return builder;
}

- (Class)classForObjectKind:(NSString *)kind {
    static NSDictionary<NSString *, Class> *classesByKind;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        classesByKind = @{
            @"t1": [RDKComment class],
            @"t2": [RDKUser class],
            @"t3": [RDKLink class],
            @"t4": [RDKMessage class],
            @"t5": [RDKSubreddit class],
            @"LabeledMulti": [RDKMultireddit class],
            @"more": [RDKMoreComments class],
        };
    });
    return kind ? classesByKind[kind] : nil;
}

- (id)objectFromJSON:(NSDictionary *)JSON {
    if (![JSON isKindOfClass:[NSDictionary class]]) {
        NSLog(@"Object from JSON not dictionary: %@", JSON);
        return nil;
    }

    Class modelClass = [self classForObjectKind:JSON[@"kind"]];
    if (!modelClass) {
        return nil;
    }

    // As in the original: a t1 that arrives with data.was_comment is an inbox
    // comment reply, not a comment in a thread
    if (modelClass == [RDKComment class] && [JSON valueForKeyPath:@"data.was_comment"] != nil) {
        modelClass = [RDKCommentReplyMessage class];
    }

    NSError *error = nil;
    id model = [MTLJSONAdapter modelOfClass:modelClass fromJSONDictionary:JSON error:&error];
    if (!model) {
        NSLog(@"Failed to build model: %@", error);
    }
    return model;
}

- (NSArray *)objectsFromListingResponse:(NSDictionary *)listing {
    NSArray *children = [listing isKindOfClass:[NSDictionary class]] ? [listing valueForKeyPath:@"data.children"] : nil;
    if (![children isKindOfClass:[NSArray class]]) {
        return @[];
    }

    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:children.count];
    for (NSDictionary *child in children) {
        id object = [self objectFromJSON:child];
        if (object) {
            [objects addObject:object];
        }
    }
    return [objects copy];
}

@end
