#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>
#import "RDKMessage.h"

// RDKCommentReplyMessage - Reddit comment reply message model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKCommentReplyMessage : RDKMessage <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *parentIdentifier;
@property (nonatomic, copy) NSString *linkIdentifier;
@property (nonatomic, copy) NSString *linkTitle;
@property (nonatomic, copy) NSString *voteStatus;
@property (nonatomic, copy) NSString *context;
@property (nonatomic, copy) NSString *parentFullName;
@property (nonatomic, copy) NSString *parentCommentBodyMarkdown;
@property (nonatomic, copy) NSString *parentCommentBodyHTML;

@end
