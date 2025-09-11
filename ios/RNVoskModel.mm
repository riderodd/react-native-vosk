#import "RNVoskModel.h"

@implementation RNVoskModel {
  VoskModel *_model;
  VoskSpkModel *_spkModel;
}

- (instancetype)initWithName:(NSString *)name error:(NSError * _Nullable __autoreleasing *)error {
  self = [super init];
  if (self) {
    // Disable logs if necessary (0 = default level; <0 = silent)
    vosk_set_log_level(0);

    NSString *normalized = [name stringByReplacingOccurrencesOfString:@"file://" withString:@""];

    // Try to open directly from the provided path
    _model = vosk_model_new([normalized UTF8String]);

    if (_model) {
      NSLog(@"Model successfully loaded from path.");
    } else {
      NSLog(@"Model directory does not exist at path: %@. Attempt to load model from main app bundle.", normalized);
      NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
      if (resourcePath != nil) {
        NSString *modelPath = [resourcePath stringByAppendingPathComponent:normalized];
        _model = vosk_model_new([modelPath UTF8String]);
      }
    }

    // Load speaker model from this library's bundle if available
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *spkPath = [bundle pathForResource:@"vosk-model-spk-0.4" ofType:nil];
    if (spkPath) {
      _spkModel = vosk_spk_model_new([spkPath UTF8String]);
    }

    if (!_model && error) {
      *error = [NSError errorWithDomain:@"Vosk" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to load Vosk model"}];
    }
  }
  return self;
}

- (void)dealloc {
  if (_model) {
    vosk_model_free(_model);
    _model = NULL;
  }
  if (_spkModel) {
    vosk_spk_model_free(_spkModel);
    _spkModel = NULL;
  }
}

- (VoskModel *)model { return _model; }
- (VoskSpkModel *)spkModel { return _spkModel; }

@end
