#import "Vosk.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "RNVoskModel.h"
#import "Vosk-API.h"

// Clé spécifique pour détecter l'exécution sur la queue de traitement
static void *kVoskProcessingQueueKey = &kVoskProcessingQueueKey;

@implementation Vosk {
  // État interne migré depuis Swift
  RNVoskModel *_Nullable _currentModel;
  VoskRecognizer *_Nullable _recognizer;
  AVAudioEngine *_audioEngine;
  AVAudioInputNode *_inputNode;
  AVAudioFormat *_formatInput;
  dispatch_queue_t _processingQueue;
  NSString *_Nullable _lastPartial;
  dispatch_source_t _Nullable _timeoutSource; // timer GCD haute perf
  // suppression de la gestion _hasListener : on émet toujours
  BOOL _isRunning; // protège l'utilisation du recognizer après stop
} RCT_EXPORT_MODULE()


- (instancetype)init {
  if ((self = [super init])) {
  _processingQueue = dispatch_queue_create("recognizerQueue", DISPATCH_QUEUE_SERIAL);
  dispatch_queue_set_specific(_processingQueue, kVoskProcessingQueueKey, kVoskProcessingQueueKey, NULL);
    _audioEngine = [AVAudioEngine new];
    _inputNode = _audioEngine.inputNode;
    _formatInput = [_inputNode inputFormatForBus:0];
    _recognizer = NULL;
    _currentModel = nil;
    _lastPartial = nil;
  _timeoutSource = nil;
    _isRunning = NO;
  }
  return self;
}

- (void)dealloc {
  if (_recognizer) {
    vosk_recognizer_free(_recognizer);
    _recognizer = NULL;
  }
}

- (NSArray<NSString *> *)supportedEvents {
  return @[ @"onError", @"onResult", @"onFinalResult", @"onPartialResult", @"onTimeout" ];
}

- (void)loadModel:(nonnull NSString *)path resolve:(nonnull RCTPromiseResolveBlock)resolve reject:(nonnull RCTPromiseRejectBlock)reject { 
  // Décharge le modèle courant si existant
  _currentModel = nil;
  NSError *err = nil;
  RNVoskModel *model = [[RNVoskModel alloc] initWithName:path error:&err];
  if (model && !err) {
    _currentModel = model;
    resolve(nil);
  } else {
    reject(@"loadModel", err.localizedDescription ?: @"Failed to load model", err);
  }
}

// Make the options nullable to avoid issues with codegen and optional fields
- (void)start:(JS::NativeVosk::VoskOptions *_Nullable)options resolve:(nonnull RCTPromiseResolveBlock)resolve reject:(nonnull RCTPromiseRejectBlock)reject {
  if (_currentModel == nil) {
    reject(@"start", @"Model not loaded", nil);
    return;
  }

  AVAudioSession *audioSession = [AVAudioSession sharedInstance];

  // Extraire options (grammar, timeout) depuis la structure codegen
  NSArray<NSString *> *grammar = nil;
  double timeoutMs = -1;

  if (options && options->grammar()) {
    auto gVec = options->grammar();
    if (gVec) {
      NSMutableArray<NSString *> *tmp = [NSMutableArray new];
      size_t count = gVec->size();
      for (size_t i = 0; i < count; ++i) {
        NSString *s = gVec->at(static_cast<int>(i));
        if (s) [tmp addObject:s];
      }
      grammar = tmp.count > 0 ? tmp : nil;
    }
  }

  if (options && options->timeout()) {
    timeoutMs = *(options->timeout());
  }

  CFAbsoluteTime tStart = CFAbsoluteTimeGetCurrent();
  @try {
    // Configurer la session audio
    NSError *err = nil;
    if (@available(iOS 10.0, *)) {
      [audioSession setCategory:AVAudioSessionCategoryRecord mode:AVAudioSessionModeMeasurement options:0 error:&err];
    } else {
      [audioSession setCategory:AVAudioSessionCategoryRecord error:&err];
    }
    if (err) { @throw [NSException exceptionWithName:@"AudioSession" reason:err.localizedDescription userInfo:nil]; }
    [audioSession setActive:YES error:&err];
    if (err) { @throw [NSException exceptionWithName:@"AudioSession" reason:err.localizedDescription userInfo:nil]; }
    _formatInput = [_inputNode inputFormatForBus:0];
    const double sampleRate = (_formatInput.sampleRate > 0) ? _formatInput.sampleRate : 16000.0;
    const uint32_t channelCount = 1;
    const AVAudioCommonFormat commonFmt = AVAudioPCMFormatInt16;
    const AVAudioFrameCount bufferSize = (AVAudioFrameCount)(sampleRate / 10.0);
    _isRunning = YES;

    __weak __typeof(self) weakSelf = self;

    // Création asynchrone du recognizer (coûteux) sur la queue de traitement
    dispatch_async(_processingQueue, ^{
      __strong __typeof(self) self = weakSelf; if (!self || !self->_isRunning) return;
      CFAbsoluteTime tRec0 = CFAbsoluteTimeGetCurrent();
      if (grammar != nil && grammar.count > 0) {
        NSError *jsonErr = nil;
        NSData *jsonGrammar = [NSJSONSerialization dataWithJSONObject:grammar options:0 error:&jsonErr];
        if (jsonGrammar && !jsonErr) {
          std::string grammarStd((const char *)[jsonGrammar bytes], [jsonGrammar length]);
          self->_recognizer = vosk_recognizer_new_grm(self->_currentModel.model, (float)sampleRate, grammarStd.c_str());
        } else {
          self->_recognizer = vosk_recognizer_new(self->_currentModel.model, (float)sampleRate);
        }
      } else {
        self->_recognizer = vosk_recognizer_new(self->_currentModel.model, (float)sampleRate);
      }
      CFAbsoluteTime tRec1 = CFAbsoluteTimeGetCurrent();
      NSLog(@"[Vosk] Recognizer init: %.2f ms", (tRec1 - tRec0)*1000.0);
      if (!self->_recognizer || !self->_isRunning) return;

      dispatch_async(dispatch_get_main_queue(), ^{
        if (!self->_isRunning) return;
        AVAudioFormat *formatPcm = [[AVAudioFormat alloc] initWithCommonFormat:commonFmt sampleRate:sampleRate channels:channelCount interleaved:YES];
        if (!formatPcm) return;
        __weak __typeof(self) weakSelfTap = self;
        [self->_inputNode installTapOnBus:0 bufferSize:bufferSize format:formatPcm block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
          __strong __typeof(self) self = weakSelfTap; if (!self) return; if (!self->_isRunning) return;
          dispatch_async(self->_processingQueue, ^{
            if (!self->_isRunning) return; VoskRecognizer *recognizer = self->_recognizer; if (!recognizer) return;
            if (!buffer.int16ChannelData || !buffer.int16ChannelData[0]) return;
            int dataLen = (int)(buffer.frameLength * 2);
            int endOfSpeech = vosk_recognizer_accept_waveform(recognizer, (const char *)buffer.int16ChannelData[0], (int32_t)dataLen);
            const char *cstr = endOfSpeech == 1 ? vosk_recognizer_result(recognizer) : vosk_recognizer_partial_result(recognizer);
            NSString *json = cstr ? [NSString stringWithUTF8String:cstr] : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
              if (!json) return; NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding]; NSDictionary *parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
              if (![parsed isKindOfClass:[NSDictionary class]]) { if (endOfSpeech == 1) { [self emitOnResult:json]; } else { [self emitOnPartialResult:json]; } return; }
              NSString *text = parsed[@"text"]; NSString *partial = parsed[@"partial"]; if (endOfSpeech == 1) { if (text.length > 0) [self emitOnResult:text]; } else { if (partial.length > 0 && (!self->_lastPartial || ![self->_lastPartial isEqualToString:partial])) { [self emitOnPartialResult:partial]; } self->_lastPartial = partial ?: self->_lastPartial; }
            });
          });
        }];
        [self->_audioEngine prepare];
        [audioSession requestRecordPermission:^(BOOL granted) {
          if (!granted) return; NSError *startErr = nil; [self->_audioEngine startAndReturnError:&startErr];
        }];
      });
    });

    // Timer GCD pour timeout
    if (timeoutMs >= 0) {
      _timeoutSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _processingQueue);
      if (_timeoutSource) {
        uint64_t delayNs = (uint64_t)(timeoutMs * 1000000.0); // ms -> ns
        dispatch_source_set_timer(_timeoutSource, dispatch_time(DISPATCH_TIME_NOW, delayNs), DISPATCH_TIME_FOREVER, 5 * NSEC_PER_MSEC);
        __weak __typeof(self) weakSelfTimeout = self;
        dispatch_source_set_event_handler(_timeoutSource, ^{
          __strong __typeof(self) selfT = weakSelfTimeout; if (!selfT) return; if (!selfT->_isRunning) return;
          [selfT stopInternalWithoutEvents:YES];
          dispatch_async(dispatch_get_main_queue(), ^{ [selfT emitOnTimeout]; });
        });
        dispatch_resume(_timeoutSource);
      }
    }

    CFAbsoluteTime tEnd = CFAbsoluteTimeGetCurrent();
    NSLog(@"[Vosk] start() sync phase: %.2f ms", (tEnd - tStart)*1000.0);
    // early resolve pour libérer JS rapidement
    resolve(nil);
    return;
  } @catch (NSException *ex) {
    // Log et émettre erreur
    NSLog(@"Error starting audio engine: %@", ex.reason);
  [self emitOnError:[NSString stringWithFormat:@"Unable to start AVAudioEngine %@", ex.reason ?: @""]];
    if (_recognizer) {
      vosk_recognizer_free(_recognizer);
      _recognizer = NULL;
    }
    reject(@"start", ex.reason ?: @"Unknown error", nil);
  }
}

- (void)stop { 
  if (!_isRunning) return; // idempotent
  [self stopInternalWithoutEvents:NO];
}

- (void)unload { 
  if (_isRunning) {
    [self stopInternalWithoutEvents:NO];
  }
  _currentModel = nil;
}

- (void)addListener:(nonnull NSString *)eventType { 
  
}


- (void)removeListeners:(double)count { 
  
}


- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const facebook::react::ObjCTurboModule::InitParams &)params { 
  return std::make_shared<facebook::react::NativeVoskSpecJSI>(params);
}

// Nettoyage interne
- (void)stopInternalWithoutEvents:(BOOL)withoutEvents {
  @try {
    [_inputNode removeTapOnBus:0];
  } @catch (...) {}

  if (!_isRunning) {
    // déjà stoppé
  }
  _isRunning = NO; // empêche nouveaux buffers d'être traités

  if (_audioEngine.isRunning) {
    [_audioEngine stop];
    if (!withoutEvents) {
      [self emitOnFinalResult:_lastPartial];
    }
    _lastPartial = nil;
  }
  // Libération du recognizer après vidage de la queue de traitement, sans deadlock si déjà sur la queue
  if (dispatch_get_specific(kVoskProcessingQueueKey)) {
    if (_recognizer) {
      vosk_recognizer_free(_recognizer);
      _recognizer = NULL;
    }
  } else {
    dispatch_sync(_processingQueue, ^{
      if (self->_recognizer) {
        vosk_recognizer_free(self->_recognizer);
        self->_recognizer = NULL;
      }
    });
  }
  if (_timeoutSource) { dispatch_source_cancel(_timeoutSource); _timeoutSource = nil; }

  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  NSError *err = nil;
  if (@available(iOS 10.0, *)) {
    [audioSession setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault options:0 error:&err];
  } else {
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&err];
  }
  [audioSession setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&err];
}

@end

