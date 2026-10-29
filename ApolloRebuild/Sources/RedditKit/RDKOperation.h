#import <Foundation/Foundation.h>

// RDKOperation - Reddit API operation model
// Reconstructed from apollo-base 1.15.11 binary analysis.

typedef void (^RDKOperationCompletion)(id response, NSError *error);

@interface RDKOperation : NSObject

+ (instancetype)operationWithMethod:(NSString *)method
                              path:(NSString *)path
                        parameters:(NSDictionary *)parameters
                        completion:(RDKOperationCompletion)completion;

@property (nonatomic, copy) NSString *method;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSDictionary *parameters;
@property (nonatomic, copy) RDKOperationCompletion completion;

@end
