#import <CoreGraphics/CoreGraphics.h>
#import "RDKVotable.h"
#import "RDKLinkPreviewItem.h"

// RDKLink - a Reddit post (kind t3)
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// The original maps ~70 fields; this covers what the feed, post cells and
// comments header use. Add fields here (property + key path + transformer if
// the JSON type differs) as screens need them.

NS_ASSUME_NONNULL_BEGIN

@interface RDKLink : RDKVotable

// Content
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *author;
@property (nonatomic, copy, nullable) NSString *subreddit;
@property (nonatomic, copy, nullable) NSString *subredditFullName;   // data.subreddit_id
@property (nonatomic, copy, nullable) NSString *domain;
@property (nonatomic, copy, nullable) NSString *URL;                 // data.url
@property (nonatomic, copy, nullable) NSString *permalink;           // "/r/sub/comments/id/slug/"
@property (nonatomic, copy, nullable) NSString *selfText;
@property (nonatomic, copy, nullable) NSString *selfTextHTML;
@property (nonatomic, copy, nullable) NSString *linkFlairText;
@property (nonatomic, copy, nullable) NSString *authorFlairPlaintext;
@property (nonatomic, copy, nullable) NSString *distinguished;       // "moderator", "admin" or nil
@property (nonatomic, copy, nullable) NSString *suggestedSort;
@property (nonatomic, copy, nullable) NSString *hint;                // data.post_hint: "image", "link", "hosted:video", ...
@property (nonatomic, copy, nullable) NSString *removedByCategory;
@property (nonatomic, strong, nullable) NSDate *edited;              // data.edited is false or a timestamp

// Flags
@property (nonatomic, assign) BOOL selfPost;        // data.is_self
@property (nonatomic, assign) BOOL isNSFW;          // data.over_18
@property (nonatomic, assign) BOOL isSpoiler;
@property (nonatomic, assign) BOOL isOC;            // data.is_original_content
@property (nonatomic, assign) BOOL isVideo;         // data.is_video (v.redd.it)
@property (nonatomic, assign) BOOL isGallery;       // data.is_gallery
@property (nonatomic, assign) BOOL stickied;
@property (nonatomic, assign) BOOL locked;
@property (nonatomic, assign) BOOL isArchived;
@property (nonatomic, assign) BOOL saved;
@property (nonatomic, assign) BOOL hidden;
@property (nonatomic, assign) BOOL visited;

// Counts
@property (nonatomic, assign) NSInteger totalComments; // data.num_comments
@property (nonatomic, assign) NSInteger gilded;
@property (nonatomic, assign) double upvoteRatio;

// Media
@property (nonatomic, copy, nullable) NSString *thumbnailURL;  // only real URLs; Reddit's "self"/"default"/"nsfw"/"spoiler" become nil
@property (nonatomic, copy, nullable) NSArray<RDKLinkPreviewItem *> *previewImages; // preview source + resolutions, narrowest first
@property (nonatomic, copy, nullable) NSString *redditVideoURL; // data.media.reddit_video.fallback_url
@property (nonatomic, assign) NSInteger galleryItemCount;       // data.gallery_data.items
@property (nonatomic, copy, nullable) NSArray<RDKLinkPreviewItem *> *galleryImages; // full-size image per gallery item, in order (from media_metadata)

// The narrowest preview at least `width` points wide on a `scale`x screen, else the widest.
// Galleries have no preview, so their first image stands in.
- (nullable RDKLinkPreviewItem *)previewImageForWidth:(CGFloat)width scale:(CGFloat)scale;
@property (nonatomic, readonly) BOOL hasPreviewImage;
@property (nonatomic, readonly) BOOL isImageLink;          // post_hint "image"
@property (nonatomic, readonly, nullable) NSURL *permalinkURL;

// Builds a link from a listing child's "data" object (no "kind" wrapper)
+ (nullable instancetype)linkWithDictionary:(nullable NSDictionary *)dictionary;
- (nullable instancetype)initWithDictionary:(nullable NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
