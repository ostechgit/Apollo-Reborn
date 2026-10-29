#import "RDKCommentReplyMessage.h"

// RDKCommentReplyMessage - Reddit comment reply message model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: parentIdentifier (NSString *)
//   +0x10: linkIdentifier (NSString *)
//   +0x18: linkTitle (NSString *)
//   +0x20: voteStatus (NSString *)
//   +0x28: context (NSString *)
//   +0x30: parentFullName (NSString *)
//   +0x38: parentCommentBodyMarkdown (NSString *)
//   +0x40: parentCommentBodyHTML (NSString *)
//
// Methods recovered:
//   - supportsSecureCoding
//   - initWithCoder:
//   - encodeWithCoder:
//   - JSONKeyPathsByPropertyKey (Mantle: extends RDKMessage with context, distinguished, linkTitle, parentFullName, voteStatus)
//   - parentIdentifier (computed)
//   - linkIdentifier (computed)
//   - urlWithContext:
//   - linkTitle
//   - voteStatus, - setVoteStatus:
//   - context
//   - parentFullName
//   - parentCommentBodyMarkdown, - setParentCommentBodyMarkdown:
//   - parentCommentBodyHTML, - setParentCommentBodyHTML:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKCommentReplyMessage

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    NSDictionary *base = [super JSONKeyPathsByPropertyKey];
    return [base mtl_dictionaryByAddingEntriesFromDictionary:@{
        @"context": @"data.context",
        @"distinguished": @"data.distinguished",
        @"linkTitle": @"data.link_title",
        @"parentFullName": @"data.parent_id",
        @"voteStatus": @"data.likes",
    }];
}

- (NSString *)parentIdentifier {
    if (!_parentFullName) {
        return nil;
    }
    NSArray *components = [_parentFullName componentsSeparatedByString:@":"];
    return components.lastObject;
}

- (NSString *)linkIdentifier {
    if (!_parentFullName) {
        return nil;
    }
    NSArray *components = [_parentFullName componentsSeparatedByString:@":"];
    return components.lastObject;
}

- (NSString *)urlWithContext:(NSString *)context {
    if (!_parentFullName) {
        return nil;
    }
    return [NSString stringWithFormat:@"https://www.reddit.com%@", _parentFullName];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _parentIdentifier = [coder decodeObjectForKey:@"parentIdentifier"];
        _linkIdentifier = [coder decodeObjectForKey:@"linkIdentifier"];
        _linkTitle = [coder decodeObjectForKey:@"linkTitle"];
        _voteStatus = [coder decodeObjectForKey:@"voteStatus"];
        _context = [coder decodeObjectForKey:@"context"];
        _parentFullName = [coder decodeObjectForKey:@"parentFullName"];
        _parentCommentBodyMarkdown = [coder decodeObjectForKey:@"parentCommentBodyMarkdown"];
        _parentCommentBodyHTML = [coder decodeObjectForKey:@"parentCommentBodyHTML"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:_parentIdentifier forKey:@"parentIdentifier"];
    [coder encodeObject:_linkIdentifier forKey:@"linkIdentifier"];
    [coder encodeObject:_linkTitle forKey:@"linkTitle"];
    [coder encodeObject:_voteStatus forKey:@"voteStatus"];
    [coder encodeObject:_context forKey:@"context"];
    [coder encodeObject:_parentFullName forKey:@"parentFullName"];
    [coder encodeObject:_parentCommentBodyMarkdown forKey:@"parentCommentBodyMarkdown"];
    [coder encodeObject:_parentCommentBodyHTML forKey:@"parentCommentBodyHTML"];
}

@end
