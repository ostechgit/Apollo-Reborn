#import "RDKComment.h"
#import "RDKObjectBuilder.h"

// RDKComment - a Reddit comment (kind t1)
// Reconstructed from apollo-base 1.15.11 binary analysis.

@implementation RDKComment

+ (NSDictionary<NSString *, id> *)JSONKeyPathsByPropertyKey {
    return [[super JSONKeyPathsByPropertyKey] mtl_dictionaryByAddingEntriesFromDictionary:@{
        @"body": @"data.body",
        @"bodyHTML": @"data.body_html",
        @"author": @"data.author",
        @"authorFlairPlaintext": @"data.author_flair_text",
        @"linkID": @"data.link_id",
        @"linkTitle": @"data.link_title",
        @"parentID": @"data.parent_id",
        @"subreddit": @"data.subreddit",
        @"distinguished": @"data.distinguished",
        @"collapsedReasonCode": @"data.collapsed_reason_code",
        @"edited": @"data.edited",
        @"isSubmitter": @"data.is_submitter",
        @"scoreHidden": @"data.score_hidden",
        @"stickied": @"data.stickied",
        @"collapsed": @"data.collapsed",
        @"saved": @"data.saved",
        @"isLocked": @"data.locked",
        @"isArchived": @"data.archived",
        @"gilded": @"data.gilded",
        @"controversiality": @"data.controversiality",
        @"depth": @"data.depth",
        @"replies": @"data.replies",
    }];
}

+ (NSValueTransformer *)editedJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(id value, BOOL *success, NSError **error) {
        if ([value isKindOfClass:[NSNumber class]] && strcmp([value objCType], @encode(char)) != 0 && [value doubleValue] > 0) {
            return [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];
        }
        return nil;
    }];
}

+ (NSValueTransformer *)repliesJSONTransformer {
    // data.replies is "" or a full {"kind": "Listing", "data": {"children": [...]}}
    return [MTLValueTransformer transformerUsingForwardBlock:^id(id value, BOOL *success, NSError **error) {
        if (![value isKindOfClass:[NSDictionary class]]) {
            return nil;
        }
        NSArray *objects = [[RDKObjectBuilder objectBuilder] objectsFromListingResponse:value];
        return objects.count > 0 ? objects : nil;
    }];
}

+ (instancetype)commentWithDictionary:(NSDictionary *)dictionary {
    return [[self alloc] initWithDictionary:dictionary];
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    return [MTLJSONAdapter modelOfClass:[self class] fromJSONDictionary:@{@"kind": @"t1", @"data": dictionary} error:nil];
}

@end
