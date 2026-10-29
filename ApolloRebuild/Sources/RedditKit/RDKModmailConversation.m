#import "RDKModmailConversation.h"

// RDKModmailConversation - Reddit modmail conversation model
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Binary layout (from .cxx_destruct and accessor analysis):
//   +0x08: conversationInfo (id)
//   +0x10: messages (NSArray *)
//   +0x18: modActions (NSArray *)
//   +0x20: user (id)
//   +0x28: firstOptionConversationInfo (id)
//   +0x30: secondOptionConversationInfo (id)
//
// Methods recovered:
//   - supportsSecureCoding
//   - allowedSecureCodingClassesByPropertyKey
//   - JSONKeyPathsByPropertyKey (Mantle)
//   - modActionsJSONTransformer (Mantle)
//   - firstOptionConversationInfoJSONTransformer (Mantle)
//   - secondOptionConversationInfoJSONTransformer (Mantle)
//   - messagesJSONTransformer (Mantle)
//   - userJSONTransformer (Mantle)
//   - conversationInfo, - setConversationInfo:
//   - messages, - setMessages:
//   - modActions, - setModActions:
//   - user, - setUser:
//   - firstOptionConversationInfo, - setFirstOptionConversationInfo:
//   - secondOptionConversationInfo, - setSecondOptionConversationInfo:
//   - .cxx_destruct (ARC cleanup)

@implementation RDKModmailConversation

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *, NSString *> *)JSONKeyPathsByPropertyKey {
    return @{
        @"conversationInfo": @"info",
        @"messages": @"messages",
        @"modActions": @"mod_actions",
        @"user": @"user",
        @"firstOptionConversationInfo": @"first_option_conversation_info",
        @"secondOptionConversationInfo": @"second_option_conversation_info",
    };
}

+ (NSValueTransformer *)modActionsJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)firstOptionConversationInfoJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)secondOptionConversationInfoJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)messagesJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

+ (NSValueTransformer *)userJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^id(id value) {
        return value;} reverseBlock:^id(id value) {
        return value;
    }];
}

@end
