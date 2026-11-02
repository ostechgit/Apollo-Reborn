#import "RDKLink.h"

// RDKLink - a Reddit post (kind t3)
// Reconstructed from apollo-base 1.15.11 binary analysis.

@implementation RDKLink

- (NSString *)previewVideoURL {
    NSDictionary *first = [(NSArray *)self.preview[@"images"] firstObject];
    if (![first isKindOfClass:NSDictionary.class]) { return nil; }
    NSString *url = first[@"variants"][@"mp4"][@"source"][@"url"];
    return [url isKindOfClass:NSString.class] ? url : nil;
}

+ (NSDictionary<NSString *, id> *)JSONKeyPathsByPropertyKey {
    return [[super JSONKeyPathsByPropertyKey] mtl_dictionaryByAddingEntriesFromDictionary:@{
        @"title": @"data.title",
        @"author": @"data.author",
        @"authorFullName": @"data.author_fullname",
        @"subreddit": @"data.subreddit",
        @"subredditFullName": @"data.subreddit_id",
        @"domain": @"data.domain",
        @"URL": @"data.url",
        @"permalink": @"data.permalink",
        @"selfText": @"data.selftext",
        @"selfTextHTML": @"data.selftext_html",
        @"linkFlairText": @"data.link_flair_text",
        @"linkFlairRichtext": @"data.link_flair_richtext",
        @"authorFlairPlaintext": @"data.author_flair_text",
        @"distinguished": @"data.distinguished",
        @"suggestedSort": @"data.suggested_sort",
        @"hint": @"data.post_hint",
        @"removedByCategory": @"data.removed_by_category",
        @"edited": @"data.edited",
        @"selfPost": @"data.is_self",
        @"isNSFW": @"data.over_18",
        @"isSpoiler": @"data.spoiler",
        @"authorCakeday": @"data.author_cakeday",
        @"isOC": @"data.is_original_content",
        @"isVideo": @"data.is_video",
        @"isGallery": @"data.is_gallery",
        @"stickied": @"data.stickied",
        @"locked": @"data.locked",
        @"isArchived": @"data.archived",
        @"saved": @"data.saved",
        @"hidden": @"data.hidden",
        @"visited": @"data.visited",
        @"totalComments": @"data.num_comments",
        @"gilded": @"data.gilded",
        @"allAwardings": @"data.all_awardings",
        @"upvoteRatio": @"data.upvote_ratio",
        @"thumbnailURL": @"data.thumbnail",
        @"crosspostParent": @"data.crosspost_parent_list",
        @"previewImages": @"data.preview.images",
        @"redditVideoURL": @"data.media.reddit_video.fallback_url",
        @"preview": @"data.preview",
        @"pollOptions": @"data.poll_data.options",
        @"pollTotalVotes": @"data.poll_data.total_vote_count",
        @"galleryItemCount": @"data.gallery_data.items",
        @"galleryImages": @[@"data.gallery_data.items", @"data.media_metadata"],
    }];
}

// MARK: - Transformers

+ (NSValueTransformer *)editedJSONTransformer {
    // false when never edited, otherwise a timestamp
    return [MTLValueTransformer transformerUsingForwardBlock:^id(id value, BOOL *success, NSError **error) {
        if ([value isKindOfClass:[NSNumber class]] && strcmp([value objCType], @encode(char)) != 0 && [value doubleValue] > 0) {
            return [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];
        }
        return nil;
    }];
}

+ (NSValueTransformer *)crosspostParentJSONTransformer {
    // data.crosspost_parent_list is an array holding the parent post's own data
    // object (not wrapped in kind/data like a listing child).
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSArray *parents, BOOL *success, NSError **error) {
        NSDictionary *parent = [parents isKindOfClass:[NSArray class]] ? parents.firstObject : nil;
        return [parent isKindOfClass:[NSDictionary class]] ? [[RDKLink alloc] initWithDictionary:parent] : nil;
    }];
}

+ (NSValueTransformer *)thumbnailURLJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSString *value, BOOL *success, NSError **error) {
        return [value isKindOfClass:[NSString class]] && [value hasPrefix:@"http"] ? value : nil;
    }];
}

+ (NSValueTransformer *)previewImagesJSONTransformer {
    // data.preview.images[0] = {"source": {url,width,height}, "resolutions": [{url,width,height}, ...]}
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSArray *images, BOOL *success, NSError **error) {
        NSDictionary *image = [images isKindOfClass:[NSArray class]] ? images.firstObject : nil;
        if (![image isKindOfClass:[NSDictionary class]]) {
            return nil;
        }
        NSMutableArray *dictionaries = [NSMutableArray array];
        if ([image[@"resolutions"] isKindOfClass:[NSArray class]]) {
            [dictionaries addObjectsFromArray:image[@"resolutions"]];
        }
        if ([image[@"source"] isKindOfClass:[NSDictionary class]]) {
            [dictionaries addObject:image[@"source"]];
        }
        NSMutableArray<RDKLinkPreviewItem *> *items = [NSMutableArray array];
        for (NSDictionary *dictionary in dictionaries) {
            RDKLinkPreviewItem *item = [MTLJSONAdapter modelOfClass:[RDKLinkPreviewItem class] fromJSONDictionary:dictionary error:nil];
            if (item.URL.length > 0 && item.width > 0 && item.height > 0) {
                [items addObject:item];
            }
        }
        [items sortUsingComparator:^NSComparisonResult(RDKLinkPreviewItem *a, RDKLinkPreviewItem *b) {
            return [@(a.width) compare:@(b.width)];
        }];
        return items.count > 0 ? [items copy] : nil;
    }];
}

+ (NSValueTransformer *)galleryItemCountJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSArray *items, BOOL *success, NSError **error) {
        return @([items isKindOfClass:[NSArray class]] ? items.count : 0);
    }];
}

+ (NSValueTransformer *)galleryImagesJSONTransformer {
    // gallery_data.items gives the order ({media_id}); media_metadata[media_id].s = {u, x, y}
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSDictionary *values, BOOL *success, NSError **error) {
        NSArray *items = values[@"data.gallery_data.items"];
        NSDictionary *metadata = values[@"data.media_metadata"];
        if (![items isKindOfClass:[NSArray class]] || ![metadata isKindOfClass:[NSDictionary class]]) {
            return nil;
        }
        NSMutableArray<RDKLinkPreviewItem *> *images = [NSMutableArray array];
        for (NSDictionary *item in items) {
            NSDictionary *media = [item isKindOfClass:[NSDictionary class]] ? metadata[item[@"media_id"]] : nil;
            NSDictionary *source = [media isKindOfClass:[NSDictionary class]] ? media[@"s"] : nil;
            if (![source isKindOfClass:[NSDictionary class]] || ![source[@"u"] isKindOfClass:[NSString class]]) {
                continue; // still processing, failed, or an animated item without a still
            }
            RDKLinkPreviewItem *image = [[RDKLinkPreviewItem alloc] init];
            image.URL = source[@"u"];
            image.width = [source[@"x"] integerValue];
            image.height = [source[@"y"] integerValue];
            if (image.width > 0 && image.height > 0) {
                [images addObject:image];
            }
        }
        return images.count > 0 ? [images copy] : nil;
    }];
}

// MARK: - Convenience

- (RDKLinkPreviewItem *)previewImageForWidth:(CGFloat)width scale:(CGFloat)scale {
    CGFloat pixelWidth = width * MAX(scale, 1);
    for (RDKLinkPreviewItem *item in self.previewImages) {
        if (item.width >= pixelWidth) {
            return item;
        }
    }
    return self.previewImages.lastObject ?: self.galleryImages.firstObject;
}

- (BOOL)hasPreviewImage {
    return self.previewImages.count > 0 || self.galleryImages.count > 0;
}

- (BOOL)isImageLink {
    return [self.hint isEqualToString:@"image"];
}

- (NSURL *)permalinkURL {
    return self.permalink.length > 0 ? [NSURL URLWithString:[@"https://www.reddit.com" stringByAppendingString:self.permalink]] : nil;
}

// MARK: - Building from a raw listing child

+ (instancetype)linkWithDictionary:(NSDictionary *)dictionary {
    return [[self alloc] initWithDictionary:dictionary];
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    return [MTLJSONAdapter modelOfClass:[self class] fromJSONDictionary:@{@"kind": @"t3", @"data": dictionary} error:nil];
}

@end
