#import <Foundation/Foundation.h>
#import "Vosk-API.h"

NS_ASSUME_NONNULL_BEGIN

// Wrapper Objective-C pour le modèle Vosk C
@interface RNVoskModel : NSObject

@property(nonatomic, assign, readonly) struct VoskModel *model;
@property(nonatomic, assign, readonly) struct VoskSpkModel *spkModel;

// name: chemin du modèle (peut être relatif au bundle ou absolu). "file://" sera ignoré.
- (instancetype)initWithName:(NSString *)name error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
