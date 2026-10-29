#import "RDKPagination.h"

// RDKPagination - listing position plus sort options
// Reconstructed from apollo-base 1.15.11 binary analysis.

NSString *RDKStringFromSubredditCategory(RDKSubredditCategory category) {
    switch (category) {
        case RDKSubredditCategoryBest: return @"best";
        case RDKSubredditCategoryNew: return @"new";
        case RDKSubredditCategoryRising: return @"rising";
        case RDKSubredditCategoryControversial: return @"controversial";
        case RDKSubredditCategoryTop: return @"top";
        default: return @"hot";
    }
}

NSString *RDKStringFromTimeSortingMethod(RDKTimeSortingMethod method) {
    switch (method) {
        case RDKTimeSortingMethodHour: return @"hour";
        case RDKTimeSortingMethodDay: return @"day";
        case RDKTimeSortingMethodWeek: return @"week";
        case RDKTimeSortingMethodMonth: return @"month";
        case RDKTimeSortingMethodYear: return @"year";
        case RDKTimeSortingMethodAllTime: return @"all";
        default: return nil;
    }
}

NSString *RDKStringFromUserContentSortingMethod(RDKUserContentSortingMethod method) {
    switch (method) {
        case RDKUserContentSortingMethodNew: return @"new";
        case RDKUserContentSortingMethodHot: return @"hot";
        case RDKUserContentSortingMethodTop: return @"top";
        case RDKUserContentSortingMethodControversial: return @"controversial";
        default: return nil;
    }
}

NSString *RDKStringFromCommentSortingMethod(RDKCommentSortingMethod method) {
    switch (method) {
        case RDKCommentSortingMethodTop: return @"top";
        case RDKCommentSortingMethodBest: return @"best";
        case RDKCommentSortingMethodNew: return @"new";
        case RDKCommentSortingMethodQA: return @"qa";
        case RDKCommentSortingMethodControversial: return @"controversial";
        case RDKCommentSortingMethodOld: return @"old";
        case RDKCommentSortingMethodRandom: return @"random";
        case RDKCommentSortingMethodLive: return @"live";
        default: return nil;
    }
}

@implementation RDKPagination

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (instancetype)paginationFromListingResponse:(NSDictionary *)response {
    if (![response isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id after = [response valueForKeyPath:@"data.after"];
    id before = [response valueForKeyPath:@"data.before"];
    if (![after isKindOfClass:[NSString class]] && ![before isKindOfClass:[NSString class]]) {
        return nil;
    }
    RDKPagination *pagination = [[RDKPagination alloc] init];
    pagination.after = [after isKindOfClass:[NSString class]] ? after : nil;
    pagination.before = [before isKindOfClass:[NSString class]] ? before : nil;
    return pagination;
}

+ (instancetype)paginationWithLimit:(NSUInteger)limit {
    RDKPagination *pagination = [[RDKPagination alloc] init];
    pagination.limit = limit;
    return pagination;
}

- (NSDictionary<NSString *, NSString *> *)dictionaryValue {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:4];
    if (self.limit > 0) {
        parameters[@"limit"] = [NSString stringWithFormat:@"%lu", (unsigned long)self.limit];
    }
    // after wins over before, as in the original
    if (self.after) {
        parameters[@"after"] = self.after;
    } else if (self.before) {
        parameters[@"before"] = self.before;
    }
    NSString *time = RDKStringFromTimeSortingMethod(self.timeMethod);
    if (time) {
        parameters[@"t"] = time;
    }
    NSString *sort = RDKStringFromUserContentSortingMethod(self.userContentSortingMethod);
    if (sort) {
        parameters[@"sort"] = sort;
    }
    return parameters.count > 0 ? [parameters copy] : nil;
}

- (id)copyWithZone:(NSZone *)zone {
    RDKPagination *copy = [[RDKPagination allocWithZone:zone] init];
    copy.limit = self.limit;
    copy.before = self.before;
    copy.after = self.after;
    copy.commentSortingMethod = self.commentSortingMethod;
    copy.userContentSortingMethod = self.userContentSortingMethod;
    copy.timeMethod = self.timeMethod;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _limit = [coder decodeIntegerForKey:@"limit"];
        _before = [coder decodeObjectOfClass:[NSString class] forKey:@"before"];
        _after = [coder decodeObjectOfClass:[NSString class] forKey:@"after"];
        _commentSortingMethod = [coder decodeIntegerForKey:@"commentSortingMethod"];
        _userContentSortingMethod = [coder decodeIntegerForKey:@"userContentSortingMethod"];
        _timeMethod = [coder decodeIntegerForKey:@"timeMethod"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.limit forKey:@"limit"];
    [coder encodeObject:self.before forKey:@"before"];
    [coder encodeObject:self.after forKey:@"after"];
    [coder encodeInteger:self.commentSortingMethod forKey:@"commentSortingMethod"];
    [coder encodeInteger:self.userContentSortingMethod forKey:@"userContentSortingMethod"];
    [coder encodeInteger:self.timeMethod forKey:@"timeMethod"];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<RDKPagination: %p; limit = %lu, before = %@, after = %@>", self, (unsigned long)self.limit, self.before, self.after];
}

@end
