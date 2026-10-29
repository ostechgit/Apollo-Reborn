#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

// RDKModmailAuthor - Reddit modmail author model
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKModmailAuthor : MTLModel <MTLJSONSerializing, NSCoding>

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) BOOL isAdmin;
@property (nonatomic, assign) BOOL isDeleted;
@property (nonatomic, assign) BOOL isHidden;
@property (nonatomic, assign) BOOL isMod;
@property (nonatomic, assign) BOOL isOP;
@property (nonatomic, assign) BOOL isParticipant;
@property (nonatomic, copy) NSString *name;

@end
