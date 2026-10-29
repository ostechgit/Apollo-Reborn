#import "RDKMedia.h"

// RDKMedia - Reddit media model (video)
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: video (id)
//
// Methods recovered:
//   - initWithCoder:
//   - encodeWithCoder:
//   - JSONKeyPathsByPropertyKey (Mantle: video -> reddit_video)
//   - videoJSONTransformer (Mantle)
//   - supportsSecureCoding
//   - video, - setVideo:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKMedia

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"video": @"reddit_video",
    };
}

+ (NSValueTransformer *)videoJSONTransformer {
    // Returns the video object as-is (Reddit API returns it directly)
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;
    } reverseBlock:^id(id value) {
        return value;
    }];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _video = [coder decodeObjectForKey:@"video"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_video forKey:@"video"];
}

@end
