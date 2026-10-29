#import <Foundation/Foundation.h>

// RDKPagination - listing position plus sort options
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Enum values match the original's lookup tables in the binary, including the
// unused slot 5 in RDKTimeSortingMethod.

NS_ASSUME_NONNULL_BEGIN

// Listing sort for front page / subreddit / multireddit links (0 also means hot)
typedef NS_ENUM(NSInteger, RDKSubredditCategory) {
    RDKSubredditCategoryHot = 1,
    RDKSubredditCategoryBest = 2,
    RDKSubredditCategoryNew = 3,
    RDKSubredditCategoryRising = 4,
    RDKSubredditCategoryControversial = 5,
    RDKSubredditCategoryTop = 6,
};

// "t" parameter for top / controversial
typedef NS_ENUM(NSInteger, RDKTimeSortingMethod) {
    RDKTimeSortingMethodNone = 0,
    RDKTimeSortingMethodHour = 1,
    RDKTimeSortingMethodDay = 2,
    RDKTimeSortingMethodWeek = 3,
    RDKTimeSortingMethodMonth = 4,
    RDKTimeSortingMethodYear = 6,
    RDKTimeSortingMethodAllTime = 7,
};

// "sort" parameter for a user's posts and comments
typedef NS_ENUM(NSInteger, RDKUserContentSortingMethod) {
    RDKUserContentSortingMethodNone = 0,
    RDKUserContentSortingMethodNew = 1,
    RDKUserContentSortingMethodHot = 2,
    RDKUserContentSortingMethodTop = 3,
    RDKUserContentSortingMethodControversial = 4,
};

// "sort" parameter for a comment thread (0 lets Reddit pick, e.g. the post's suggested sort)
typedef NS_ENUM(NSInteger, RDKCommentSortingMethod) {
    RDKCommentSortingMethodDefault = 0,
    RDKCommentSortingMethodTop = 1,
    RDKCommentSortingMethodBest = 2,
    RDKCommentSortingMethodNew = 3,
    RDKCommentSortingMethodQA = 4,
    RDKCommentSortingMethodControversial = 5,
    RDKCommentSortingMethodOld = 6,
    RDKCommentSortingMethodRandom = 7,
};

FOUNDATION_EXPORT NSString *_Nullable RDKStringFromSubredditCategory(RDKSubredditCategory category);
FOUNDATION_EXPORT NSString *_Nullable RDKStringFromTimeSortingMethod(RDKTimeSortingMethod method);
FOUNDATION_EXPORT NSString *_Nullable RDKStringFromUserContentSortingMethod(RDKUserContentSortingMethod method);
FOUNDATION_EXPORT NSString *_Nullable RDKStringFromCommentSortingMethod(RDKCommentSortingMethod method);

@interface RDKPagination : NSObject <NSSecureCoding, NSCopying>

@property (nonatomic, assign) NSUInteger limit;
@property (nonatomic, copy, nullable) NSString *before;
@property (nonatomic, copy, nullable) NSString *after;
@property (nonatomic, assign) RDKCommentSortingMethod commentSortingMethod;
@property (nonatomic, assign) RDKUserContentSortingMethod userContentSortingMethod;
@property (nonatomic, assign) RDKTimeSortingMethod timeMethod;

// Position of the next page from a listing response's data.after / data.before; nil at the end
+ (nullable instancetype)paginationFromListingResponse:(nullable NSDictionary *)response;
+ (instancetype)paginationWithLimit:(NSUInteger)limit;

// Query parameters: limit, after (or before), t, sort; nil when there are none
- (nullable NSDictionary<NSString *, NSString *> *)dictionaryValue;

@end

NS_ASSUME_NONNULL_END
