// Host-side tests for the RedditKit model layer (RDKLink, RDKComment, RDKMoreComments,
// RDKObjectBuilder, RDKPagination) against the JSON fixtures in fixtures/.
// Run with tests/run_redditkit_model_tests.sh.

#import <Foundation/Foundation.h>
#import "RDKLink.h"
#import "RDKComment.h"
#import "RDKMoreComments.h"
#import "RDKObjectBuilder.h"
#import "RDKPagination.h"

static int failures = 0;
static int checks = 0;

#define CHECK(cond, ...) do { \
    checks++; \
    if (!(cond)) { failures++; fprintf(stderr, "FAIL %s:%d: %s — %s\n", __FILE__, __LINE__, #cond, [[NSString stringWithFormat:__VA_ARGS__] UTF8String]); } \
} while (0)

static id LoadFixture(NSString *directory, NSString *name) {
    NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:name]];
    return data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
}

static void TestListing(NSDictionary *listing) {
    NSArray *links = [[RDKObjectBuilder objectBuilder] objectsFromListingResponse:listing];
    CHECK(links.count == 6, @"expected 6 links, got %lu", (unsigned long)links.count);
    if (links.count != 6) return;
    for (id link in links) {
        CHECK([link isKindOfClass:[RDKLink class]], @"%@ is not an RDKLink", link);
    }

    RDKPagination *pagination = [RDKPagination paginationFromListingResponse:listing];
    CHECK([pagination.after isEqualToString:@"t3_1fx0006"], @"after = %@", pagination.after);
    CHECK(pagination.before == nil, @"before = %@", pagination.before);

    // Self post, stickied mod post, unvoted
    RDKLink *selfPost = links[0];
    CHECK([selfPost.fullName isEqualToString:@"t3_1fx0001"], @"fullName = %@", selfPost.fullName);
    CHECK([selfPost.identifier isEqualToString:@"1fx0001"], @"identifier = %@", selfPost.identifier);
    CHECK([selfPost.kindName isEqualToString:@"t3"], @"kindName = %@", selfPost.kindName);
    CHECK(selfPost.selfPost && selfPost.stickied, @"self/stickied flags");
    CHECK([selfPost.distinguished isEqualToString:@"moderator"], @"distinguished = %@", selfPost.distinguished);
    CHECK(selfPost.voteStatus == RDKVoteStatusNone && !selfPost.voted, @"likes null -> none, got %lu", (unsigned long)selfPost.voteStatus);
    CHECK(selfPost.thumbnailURL == nil, @"\"self\" thumbnail should be nil, got %@", selfPost.thumbnailURL);
    CHECK(selfPost.edited == nil, @"edited false -> nil, got %@", selfPost.edited);
    CHECK(fabs(selfPost.createdUTC.timeIntervalSince1970 - 1761600000.0) < 0.001, @"createdUTC = %@", selfPost.createdUTC);
    CHECK(selfPost.totalComments == 128 && selfPost.score == 42, @"counts %ld / %ld", (long)selfPost.totalComments, (long)selfPost.score);
    CHECK([selfPost.linkFlairText isEqualToString:@"Weekly"], @"flair = %@", selfPost.linkFlairText);
    CHECK(!selfPost.hasPreviewImage, @"self post has no preview");
    CHECK([selfPost.permalinkURL.absoluteString isEqualToString:@"https://www.reddit.com/r/iOSProgramming/comments/1fx0001/weekly_discussion_thread/"], @"permalinkURL = %@", selfPost.permalinkURL);

    // Image post, upvoted, saved, edited, OC
    RDKLink *image = links[1];
    CHECK(image.voteStatus == RDKVoteStatusUpvoted && image.upvoted, @"likes true -> upvoted, got %lu", (unsigned long)image.voteStatus);
    CHECK(image.saved && image.isOC && image.gilded == 2, @"saved/OC/gilded");
    CHECK(image.isImageLink, @"post_hint image");
    CHECK(fabs(image.edited.timeIntervalSince1970 - 1761595000.5) < 0.001, @"edited = %@", image.edited);
    CHECK([image.thumbnailURL hasPrefix:@"https://b.thumbs"], @"thumbnail = %@", image.thumbnailURL);
    CHECK(image.previewImages.count == 5, @"4 resolutions + source, got %lu", (unsigned long)image.previewImages.count);
    NSArray *widths = [image.previewImages valueForKey:@"width"];
    CHECK([widths isEqualToArray:(@[@108, @216, @640, @1080, @4032])], @"widths not ascending: %@", widths);
    CHECK([image previewImageForWidth:300 scale:2].width == 640, @"300pt@2x -> 640, got %ld", (long)[image previewImageForWidth:300 scale:2].width);
    CHECK([image previewImageForWidth:390 scale:3].width == 4032, @"390pt@3x -> source, got %ld", (long)[image previewImageForWidth:390 scale:3].width);
    CHECK(fabs(image.upvoteRatio - 0.98) < 0.0001, @"ratio = %f", image.upvoteRatio);
    CHECK([image.authorFlairPlaintext isEqualToString:@"Photographer"], @"author flair = %@", image.authorFlairPlaintext);

    // Link post, downvoted, locked, visited
    RDKLink *article = links[2];
    CHECK(article.voteStatus == RDKVoteStatusDownvoted && article.downvoted, @"likes false -> downvoted, got %lu", (unsigned long)article.voteStatus);
    CHECK(article.locked && article.visited, @"locked/visited");
    CHECK([article.domain isEqualToString:@"swift.org"], @"domain = %@", article.domain);
    CHECK(article.previewImages.count == 2, @"previews = %lu", (unsigned long)article.previewImages.count);

    // v.redd.it video
    RDKLink *video = links[3];
    CHECK(video.isVideo, @"is_video");
    CHECK([video.redditVideoURL hasPrefix:@"https://v.redd.it/vid0004/DASH_720.mp4"], @"video URL = %@", video.redditVideoURL);
    CHECK(video.score == 52310, @"score = %ld", (long)video.score);

    // Gallery
    RDKLink *gallery = links[4];
    CHECK(gallery.isGallery && gallery.galleryItemCount == 3, @"gallery %d / %ld", gallery.isGallery, (long)gallery.galleryItemCount);
    CHECK(gallery.previewImages == nil, @"galleries carry media_metadata, not preview");
    CHECK(gallery.galleryImages.count == 1, @"one valid media_metadata item of three, got %lu", (unsigned long)gallery.galleryImages.count);
    CHECK(gallery.hasPreviewImage && [gallery previewImageForWidth:390 scale:3].width == 3000, @"first gallery image stands in for the preview");
    CHECK([gallery.galleryImages.firstObject.URL hasPrefix:@"https://preview.redd.it/g1.jpg"], @"gallery URL = %@", gallery.galleryImages.firstObject.URL);

    // Removed NSFW spoiler, archived
    RDKLink *removed = links[5];
    CHECK(removed.isNSFW && removed.isSpoiler && removed.isArchived, @"nsfw/spoiler/archived");
    CHECK(removed.thumbnailURL == nil, @"\"spoiler\" thumbnail should be nil, got %@", removed.thumbnailURL);
    CHECK([removed.removedByCategory isEqualToString:@"moderator"], @"removed_by_category = %@", removed.removedByCategory);

    // Building straight from a child's data object
    RDKLink *fromData = [RDKLink linkWithDictionary:listing[@"data"][@"children"][1][@"data"]];
    CHECK([fromData.fullName isEqualToString:@"t3_1fx0002"] && fromData.upvoted, @"linkWithDictionary: %@", fromData);
    CHECK([RDKLink linkWithDictionary:nil] == nil, @"nil dictionary -> nil");
    CHECK([image isEqual:fromData] && image.hash == fromData.hash, @"equality by fullName");
}

static void TestComments(NSArray *response) {
    CHECK([response isKindOfClass:[NSArray class]] && response.count == 2, @"comments response is [link listing, comment listing]");
    if (response.count != 2) return;

    NSArray *linkObjects = [[RDKObjectBuilder objectBuilder] objectsFromListingResponse:response[0]];
    CHECK(linkObjects.count == 1 && [linkObjects.firstObject isKindOfClass:[RDKLink class]], @"link half: %@", linkObjects);
    CHECK(((RDKLink *)linkObjects.firstObject).thumbnailURL == nil, @"\"default\" thumbnail should be nil");

    NSArray *top = [[RDKObjectBuilder objectBuilder] objectsFromListingResponse:response[1]];
    CHECK(top.count == 3, @"3 top-level things, got %lu", (unsigned long)top.count);
    if (top.count != 3) return;

    RDKComment *first = top[0];
    CHECK([first isKindOfClass:[RDKComment class]], @"%@ is not a comment", first);
    CHECK([first.author isEqualToString:@"first_commenter"] && first.score == 512, @"author/score");
    CHECK([first.parentID isEqualToString:@"t3_1fx0002"] && [first.linkID isEqualToString:@"t3_1fx0002"], @"parent/link IDs");
    CHECK(first.depth == 0 && first.edited == nil && first.voteStatus == RDKVoteStatusNone, @"depth/edited/vote");
    CHECK(first.replies.count == 2, @"2 replies, got %lu", (unsigned long)first.replies.count);
    if (first.replies.count == 2) {
        RDKComment *reply = (RDKComment *)first.replies[0];
        CHECK([reply isKindOfClass:[RDKComment class]], @"reply class %@", reply.class);
        CHECK(reply.isSubmitter && reply.upvoted && reply.depth == 1, @"OP reply flags");
        CHECK(reply.edited != nil && reply.replies == nil, @"edited timestamp, \"\" replies -> nil");
        RDKMoreComments *more = (RDKMoreComments *)first.replies[1];
        CHECK([more isKindOfClass:[RDKMoreComments class]], @"more class %@", more.class);
        CHECK(more.count == 14 && more.children.count == 3 && !more.isContinueThread, @"more stub %@", more);
        CHECK([more.parentID isEqualToString:@"t1_c001"], @"more parent = %@", more.parentID);
    }

    RDKComment *deleted = top[1];
    CHECK([deleted isKindOfClass:[RDKComment class]], @"deleted comment still parses");
    CHECK(deleted.collapsed && deleted.scoreHidden && deleted.gilded == 0, @"collapsed/score hidden/null gilded");
    CHECK([deleted.collapsedReasonCode isEqualToString:@"DELETED"], @"reason = %@", deleted.collapsedReasonCode);

    RDKMoreComments *continueThread = top[2];
    CHECK([continueThread isKindOfClass:[RDKMoreComments class]] && continueThread.isContinueThread, @"continue-thread stub");
    RDKMoreComments *countBased = [RDKMoreComments new];
    countBased.count = 2; countBased.children = @[];
    CHECK(!countBased.isContinueThread, @"positive count with empty children is not Continue Thread");
    countBased.count = 0; countBased.children = @[@"child"];
    CHECK(countBased.isContinueThread, @"zero count determines Continue Thread, not children");
}

static void TestPagination(void) {
    RDKPagination *pagination = [RDKPagination paginationWithLimit:25];
    CHECK([pagination.dictionaryValue isEqualToDictionary:@{@"limit": @"25"}], @"%@", pagination.dictionaryValue);
    pagination.after = @"t3_after";
    pagination.before = @"t3_before";
    pagination.timeMethod = RDKTimeSortingMethodYear;
    pagination.userContentSortingMethod = RDKUserContentSortingMethodTop;
    NSDictionary *expected = @{@"limit": @"25", @"after": @"t3_after", @"t": @"year", @"sort": @"top"};
    CHECK([pagination.dictionaryValue isEqualToDictionary:expected], @"%@", pagination.dictionaryValue);
    CHECK([[RDKPagination new] dictionaryValue] == nil, @"empty pagination -> nil parameters");
    NSDictionary *endOfListing = @{@"data": @{@"after": [NSNull null], @"before": [NSNull null]}};
    CHECK([RDKPagination paginationFromListingResponse:endOfListing] == nil, @"end of listing -> nil");

    CHECK([RDKStringFromSubredditCategory(0) isEqualToString:@"hot"] && [RDKStringFromSubredditCategory(RDKSubredditCategoryTop) isEqualToString:@"top"], @"categories");
    CHECK(RDKStringFromTimeSortingMethod(5) == nil && [RDKStringFromTimeSortingMethod(RDKTimeSortingMethodAllTime) isEqualToString:@"all"], @"time table");
    CHECK([RDKStringFromCommentSortingMethod(RDKCommentSortingMethodQA) isEqualToString:@"qa"] && RDKStringFromCommentSortingMethod(0) == nil, @"comment sorts");

    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:pagination requiringSecureCoding:YES error:nil];
    RDKPagination *restored = [NSKeyedUnarchiver unarchivedObjectOfClass:[RDKPagination class] fromData:archive error:nil];
    CHECK([restored.dictionaryValue isEqualToDictionary:expected], @"secure coding round trip: %@", restored.dictionaryValue);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *fixtures = argc > 1 ? @(argv[1]) : @"fixtures";
        NSDictionary *listing = LoadFixture(fixtures, @"listing-hot.json");
        NSArray *comments = LoadFixture(fixtures, @"comments-thread.json");
        CHECK(listing != nil && comments != nil, @"fixtures load from %@", fixtures);

        TestListing(listing);
        TestComments(comments);
        TestPagination();

        printf("%d checks, %d failures\n", checks, failures);
        return failures == 0 ? 0 : 1;
    }
}
