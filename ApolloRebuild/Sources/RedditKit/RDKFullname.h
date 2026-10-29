#import <Foundation/Foundation.h>

// RDKFullname - Reddit fullname parser (t[0-9]_[a-zA-Z0-9_-]+)
// Reconstructed from apollo-base 1.15.11 binary analysis.

@interface RDKFullname : NSObject

- (instancetype)initWithFullName:(NSString *)fullName;
- (NSString *)identifier;
- (BOOL)isValid;

@property (nonatomic, copy) NSString *fullName;

@end
