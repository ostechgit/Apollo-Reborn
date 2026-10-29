#import "RDKOperation.h"

// RDKOperation - Reddit API operation model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: method (NSString *)
//   +0x10: path (NSString *)
//   +0x18: parameters (NSDictionary *)
//   +0x20: completion (RDKOperationCompletion)
//
// Methods recovered:
//   + operationWithMethod:path:parameters:completion: (factory method)
//   - isEqual: (compare by method, path, parameters)
//   - hash
//   - method, - setMethod:
//   - path, - setPath:
//   - parameters, - setParameters:
//   - completion, - setCompletion:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKOperation {
    NSString *_method;
    NSString *_path;
    NSDictionary *_parameters;
    RDKOperationCompletion _completion;
}

+ (instancetype)operationWithMethod:(NSString *)method
                              path:(NSString *)path
                        parameters:(NSDictionary *)parameters
                        completion:(RDKOperationCompletion)completion {
    RDKOperation *operation = [[RDKOperation alloc] init];
    operation.method = method;
    operation.path = path;
    operation.parameters = parameters;
    operation.completion = completion;
    return operation;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[RDKOperation class]]) {
        return NO;
    }
    RDKOperation *other = (RDKOperation *)object;
    if (_method != other.method) {
        return NO;
    }
    if (_path != other.path) {
        return NO;
    }
    return [_parameters isEqualToDictionary:other.parameters];
}

- (NSUInteger)hash {
    return [_method hash] ^ [_path hash] ^ [_parameters hash];
}

@end
