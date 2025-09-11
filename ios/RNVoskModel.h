#import <Foundation/Foundation.h>
#import "Vosk-API.h"

NS_ASSUME_NONNULL_BEGIN

// Objective-C wrapper for Vosk C model
@interface RNVoskModel : NSObject

@property(nonatomic, assign, readonly) struct VoskModel *model;
@property(nonatomic, assign, readonly) struct VoskSpkModel *spkModel;

// name: model path (can be relative to bundle or absolute). "file://" will be ignored.
- (instancetype)initWithName:(NSString *)name error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
