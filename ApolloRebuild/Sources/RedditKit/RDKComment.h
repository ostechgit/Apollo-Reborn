#import "RDKVotable.h"

// RDKComment - a Reddit comment (kind t1)
// Reconstructed from apollo-base 1.15.11 binary analysis.

NS_ASSUME_NONNULL_BEGIN

@interface RDKComment : RDKVotable

@property (nonatomic, copy, nullable) NSString *body;
@property (nonatomic, copy, nullable) NSString *bodyHTML;
@property (nonatomic, copy, nullable) NSString *author;
@property (nonatomic, copy, nullable) NSString *authorFullName;  // data.author_fullname (t2_…)
@property (nonatomic, copy, nullable) NSString *authorFlairPlaintext;
@property (nonatomic, copy, nullable) NSString *linkID;       // data.link_id, e.g. "t3_1abc2d"
@property (nonatomic, copy, nullable) NSString *linkTitle;    // only present outside a thread (profile, inbox)
@property (nonatomic, copy, nullable) NSString *parentID;     // data.parent_id: a t1_ or t3_ fullname
@property (nonatomic, copy, nullable) NSString *subreddit;
@property (nonatomic, copy, nullable) NSString *distinguished;
@property (nonatomic, copy, nullable) NSString *collapsedReasonCode;
@property (nonatomic, strong, nullable) NSDate *edited;
/// data.media_metadata: Reddit's own sizing for any image or gif embedded in
/// the body, keyed by media id ("giphy|ID" for giphy embeds).
@property (nonatomic, copy, nullable) NSDictionary *mediaMetadata;

@property (nonatomic, assign) BOOL isSubmitter;   // data.is_submitter (OP)
@property (nonatomic, assign) BOOL scoreHidden;
@property (nonatomic, assign) BOOL stickied;
@property (nonatomic, assign) BOOL collapsed;
@property (nonatomic, assign) BOOL saved;
@property (nonatomic, assign) BOOL isLocked;      // data.locked
@property (nonatomic, assign) BOOL isArchived;    // data.archived
@property (nonatomic, assign) NSInteger gilded;
/// data.author_cakeday — true only on the author's cake day.
@property (nonatomic, assign) BOOL authorCakeday;
/// data.all_awardings, kept raw so the icons can be read without a new model.
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *allAwardings;
@property (nonatomic, assign) NSInteger controversiality;
@property (nonatomic, assign) NSInteger depth;

// Direct replies: RDKComment and RDKMoreComments objects ("" in the JSON when there are none)
@property (nonatomic, copy, nullable) NSArray<RDKThing *> *replies;

// Builds a comment from a listing child's "data" object (no "kind" wrapper)
+ (nullable instancetype)commentWithDictionary:(nullable NSDictionary *)dictionary;
- (nullable instancetype)initWithDictionary:(nullable NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
