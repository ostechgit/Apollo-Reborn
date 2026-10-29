#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>
#import "RDKCreated.h"

// RDKModeratorAction - Reddit moderator action model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKModeratorAction : RDKCreated <MTLJSONSerializing>

@property (nonatomic, copy) NSString *fullName;
@property (nonatomic, copy) NSString *action;
@property (nonatomic, copy) NSString *details;
@property (nonatomic, copy) NSString *moderatorUsername;
@property (nonatomic, copy) NSString *moderatorIdentifier;
@property (nonatomic, copy) NSString *subredditName;
@property (nonatomic, copy) NSString *subredditIdentifier;
@property (nonatomic, copy) NSString *targetFullName;
@property (nonatomic, copy) NSString *targetPermalink;
@property (nonatomic, copy) NSString *targetAuthor;
@property (nonatomic, copy) NSString *targetTitle;
@property (nonatomic, copy) NSString *targetBody;
@property (nonatomic, copy) NSString *modDescription;

@end
