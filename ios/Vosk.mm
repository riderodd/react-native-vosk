#import "Vosk.h"
#import "RNVoskModel.h"
#import "Vosk-API.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#include <vector> // added for float32 -> int16 conversion

// Specific key to detect execution on the processing queue
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
  dispatch_source_t _Nullable _timeoutSource; // high-performance GCD timer
  // removed _hasListener management: we always emit
  BOOL _isRunning; // protects use of recognizer after stop
  BOOL _isStarting; // prevents concurrent start
  BOOL _tapInstalled; // track tap installation
  BOOL _pendingTap; // indicates we are retrying tap installation
  int _tapRetryCount; // retry counter
}
RCT_EXPORT_MODULE()

- (instancetype)init {
  if ((self = [super init])) {
    _processingQueue =
        dispatch_queue_create("recognizerQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(_processingQueue, kVoskProcessingQueueKey,
                                kVoskProcessingQueueKey, NULL);
    // Lazy initialization to avoid triggering microphone permission prompt
    _audioEngine = nil;
    _inputNode = nil;
    _formatInput = nil;
    _recognizer = NULL;
    _currentModel = nil;
    _lastPartial = nil;
    _timeoutSource = nil;
    _isRunning = NO;
    _isStarting = NO;
    _tapInstalled = NO;
    _pendingTap = NO;
    _tapRetryCount = 0;
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
  return @[
    @"onError", @"onResult", @"onFinalResult", @"onPartialResult", @"onTimeout"
  ];
}

- (void)loadModel:(nonnull NSString *)path
          resolve:(nonnull RCTPromiseResolveBlock)resolve
           reject:(nonnull RCTPromiseRejectBlock)reject {
  // Unload the current model if any
  _currentModel = nil;
  NSError *err = nil;
  RNVoskModel *model = [[RNVoskModel alloc] initWithName:path error:&err];
  if (model && !err) {
    _currentModel = model;
    resolve(nil);
  } else {
    reject(@"loadModel", err.localizedDescription ?: @"Failed to load model",
           err);
  }
}

// Make the options nullable to avoid issues with codegen and optional fields
- (void)start:(JS::NativeVosk::VoskOptions *_Nullable)options
      resolve:(nonnull RCTPromiseResolveBlock)resolve
       reject:(nonnull RCTPromiseRejectBlock)reject {
  if (_currentModel == nil) {
    reject(@"start", @"Model not loaded", nil);
    return;
  }
  if (_isStarting || _isRunning) {
    reject(@"start", @"Recognizer already starting or running", nil);
    return;
  }
  _isStarting = YES;
  _tapRetryCount = 0;
  _pendingTap = NO;
  
  // Lazy initialization of audio engine to avoid permission prompt at module load
  if (!_audioEngine) {
    _audioEngine = [AVAudioEngine new];
  }
  if (!_inputNode) {
    _inputNode = _audioEngine.inputNode;
  }
  
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];

  // Extract options (grammar, timeout) from the codegen structure
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
  // Configure session category first (allowed even before permission)
  NSError *catErr = nil;
  @try {
    if (@available(iOS 10.0, *)) {
      [audioSession setCategory:AVAudioSessionCategoryRecord
                           mode:AVAudioSessionModeMeasurement
                        options:0
                          error:&catErr];
    } else {
      [audioSession setCategory:AVAudioSessionCategoryRecord error:&catErr];
    }
    if (catErr) {
      NSString *msg = [NSString stringWithFormat:@"Audio session category error: %@", catErr.localizedDescription];
      [self emitOnError:msg];
      _isStarting = NO;
      reject(@"start", msg, catErr);
      return;
    }
  } @catch (NSException *ex) {
    NSString *msg = [NSString stringWithFormat:@"Exception setting category: %@", ex.reason ?: @"unknown"]; 
    [self emitOnError:msg];
    _isStarting = NO;
    reject(@"start", msg, nil);
    return;
  }

  // Request permission BEFORE doing heavy work
  [audioSession requestRecordPermission:^(BOOL granted) {
    if (!granted) {
      dispatch_async(dispatch_get_main_queue(), ^{
        NSString *msg = @"Microphone permission denied";
        [self emitOnError:msg];
        self->_isStarting = NO;
        reject(@"start", msg, nil);
      });
      return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{ // proceed on main
      NSError *actErr = nil;
      if (![audioSession setActive:YES error:&actErr]) {
        NSString *msg = [NSString stringWithFormat:@"Failed to activate audio session: %@", actErr.localizedDescription];
        [self emitOnError:msg];
        self->_isStarting = NO;
        reject(@"start", msg, actErr);
        return;
      }

  self->_formatInput = [self->_inputNode inputFormatForBus:0];
  const double sampleRate = (self->_formatInput.sampleRate > 0) ? self->_formatInput.sampleRate : 16000.0;
  const AVAudioFrameCount bufferSize = (AVAudioFrameCount)(sampleRate / 10.0);
  self->_isRunning = YES;

      __weak __typeof(self) weakSelf = self;
      dispatch_async(self->_processingQueue, ^{ // recognizer init off main
        __strong __typeof(self) self = weakSelf;
        if (!self || !self->_isRunning) return;
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
        NSLog(@"[Vosk] Recognizer init: %.2f ms", (tRec1 - tRec0) * 1000.0);
        if (!self->_recognizer) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [self emitOnError:@"Recognizer initialization failed (null)"];
            reject(@"start", @"Recognizer initialization failed", nil);
            self->_isStarting = NO;
          });
          return; // promise already resolved later below or not? -> we won't resolve now
        }

        dispatch_async(dispatch_get_main_queue(), ^{ // start engine first
          if (!self->_isRunning) { self->_isStarting = NO; return; }
          [self->_audioEngine prepare];
          NSError *startErr = nil;
          if (![self->_audioEngine startAndReturnError:&startErr]) {
            NSString *msg = [NSString stringWithFormat:@"Failed to start audio engine: %@", startErr.localizedDescription];
            [self emitOnError:msg];
            [self stopInternalWithoutEvents:YES];
            self->_isStarting = NO;
            reject(@"start", msg, startErr);
            return;
          }
          // Timeout timer
          if (timeoutMs >= 0) {
            self->_timeoutSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self->_processingQueue);
            if (self->_timeoutSource) {
              uint64_t delayNs = (uint64_t)(timeoutMs * 1000000.0);
              __weak __typeof(self) weakSelfTimeout = self;
              dispatch_source_set_timer(self->_timeoutSource, dispatch_time(DISPATCH_TIME_NOW, delayNs), DISPATCH_TIME_FOREVER, 5 * NSEC_PER_MSEC);
              dispatch_source_set_event_handler(self->_timeoutSource, ^{ __strong __typeof(self) selfT = weakSelfTimeout; if (!selfT || !selfT->_isRunning) return; [selfT stopInternalWithoutEvents:YES]; dispatch_async(dispatch_get_main_queue(), ^{ [selfT emitOnTimeout]; }); });
              dispatch_resume(self->_timeoutSource);
            }
          }
          CFAbsoluteTime tEnd = CFAbsoluteTimeGetCurrent();
          NSLog(@"[Vosk] start() engine running (tap pending): %.2f ms", (tEnd - tStart) * 1000.0);
          // Resolve early; tap installation will be async via retry
          resolve(nil);
          self->_isStarting = NO;
          self->_pendingTap = YES;
          self->_tapRetryCount = 0;
          [self scheduleTapInstallationWithBufferSize:bufferSize];
        });
      });
    });
  }];
}

// Retry-based tap installer; called on main queue only
- (void)scheduleTapInstallationWithBufferSize:(AVAudioFrameCount)bufferSize {
  if (!_isRunning) { _pendingTap = NO; return; }
  if (_tapInstalled) { _pendingTap = NO; return; }
  if (!_recognizer) { _pendingTap = NO; return; }
  AVAudioFormat *fmt = [_inputNode inputFormatForBus:0];
  double sr = fmt ? fmt.sampleRate : 0.0;
  AVAudioChannelCount ch = fmt ? fmt.channelCount : 0;
  if (sr <= 0.0 || ch == 0) {
    if (_tapRetryCount == 0) {
      NSLog(@"[Vosk] Tap install waiting for valid format… (sr=%.1f ch=%u)", sr, (unsigned int)ch);
    }
    if (_tapRetryCount >= 25) { // ~2.5s at 100ms intervals
      [self emitOnError:@"Unable to obtain valid audio input format (stabilization timeout)"]; _pendingTap = NO; return; }
    _tapRetryCount++;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self scheduleTapInstallationWithBufferSize:bufferSize]; });
    return;
  }
  // Have a valid format now
  NSLog(@"[Vosk] Tap install attempt with format sr=%.1f ch=%u retry=%d", sr, (unsigned int)ch, _tapRetryCount);
  __weak __typeof(self) weakSelfTap = self;
  @try {
    [_inputNode installTapOnBus:0 bufferSize:bufferSize format:fmt block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
      __strong __typeof(self) self = weakSelfTap; if (!self) return; if (!self->_isRunning) return;
      dispatch_async(self->_processingQueue, ^{
        if (!self->_isRunning) return; VoskRecognizer *recognizer = self->_recognizer; if (!recognizer) return;
        AVAudioFrameCount frames = buffer.frameLength; if (frames == 0) return;
        int accepted = 0;
        if (buffer.int16ChannelData && buffer.int16ChannelData[0]) {
          int dataLen = (int)(frames * sizeof(int16_t));
          accepted = vosk_recognizer_accept_waveform(recognizer, (const char *)buffer.int16ChannelData[0], (int32_t)dataLen);
        } else if (buffer.floatChannelData && buffer.floatChannelData[0]) {
          float *const *floatChannels = buffer.floatChannelData; std::vector<int16_t> pcm16; pcm16.resize(frames); float *ch0 = floatChannels[0];
          for (AVAudioFrameCount i = 0; i < frames; ++i) { float s = ch0[i]; if (s > 1.f) s = 1.f; else if (s < -1.f) s = -1.f; pcm16[i] = (int16_t)lrintf(s * 32767.f); }
          int dataLen = (int)(frames * sizeof(int16_t));
          accepted = vosk_recognizer_accept_waveform(recognizer, (const char *)pcm16.data(), (int32_t)dataLen);
        } else { return; }
        const char *cstr = NULL; BOOL isFinal = NO; if (accepted) { cstr = vosk_recognizer_result(recognizer); isFinal = YES; } else { cstr = vosk_recognizer_partial_result(recognizer); }
        NSString *json = cstr ? [NSString stringWithUTF8String:cstr] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{ if (!json) return; NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding]; NSDictionary *parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil; if (![parsed isKindOfClass:[NSDictionary class]]) { if (isFinal) { [self emitOnResult:json]; } else { [self emitOnPartialResult:json]; } return; } NSString *text = parsed[@"text"]; NSString *partial = parsed[@"partial"]; if (isFinal) { if (text.length > 0) { [self emitOnResult:text]; } self->_lastPartial = nil; } else { if (partial.length > 0 && (!self->_lastPartial || ![self->_lastPartial isEqualToString:partial])) { [self emitOnPartialResult:partial]; } self->_lastPartial = partial ?: self->_lastPartial; } });
      });
    }];
    _tapInstalled = YES; _pendingTap = NO; NSLog(@"[Vosk] Tap installed successfully after %d retries.", _tapRetryCount);
  } @catch (NSException *ex) {
    [self emitOnError:[NSString stringWithFormat:@"Failed to install tap (retry phase): %@", ex.reason ?: @"unknown"]];
    _pendingTap = NO; [self stopInternalWithoutEvents:YES];
  }
}

- (void)stop {
  if (!_isRunning)
    return; // idempotent
  [self stopInternalWithoutEvents:NO];
}

- (void)unload {
  if (_isRunning) {
    [self stopInternalWithoutEvents:NO];
  }
  // Reset all flags to ensure consistent state regardless of running state
  _isStarting = NO;
  _isRunning = NO;
  _tapInstalled = NO;
  _pendingTap = NO;
  _tapRetryCount = 0;
  _currentModel = nil;
}

- (void)addListener:(nonnull NSString *)eventType {
}

- (void)removeListeners:(double)count {
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeVoskSpecJSI>(params);
}

// Internal cleanup
- (void)stopInternalWithoutEvents:(BOOL)withoutEvents {
  // Reset flags immediately to allow restart
  _isRunning = NO;
  _isStarting = NO;
  _tapInstalled = NO;
  _pendingTap = NO;
  
  @try {
    if (_inputNode) {
      [_inputNode removeTapOnBus:0];
    }
  } @catch (...) {
  }

  if (_audioEngine.isRunning) {
    [_audioEngine stop];
    if (!withoutEvents) {
      [self emitOnFinalResult:_lastPartial];
    }
    _lastPartial = nil;
  }
  // Recognizer cleanup after draining processing queue, without deadlock if
  // already on the queue
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
  if (_timeoutSource) {
    dispatch_source_cancel(_timeoutSource);
    _timeoutSource = nil;
  }

  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  NSError *err = nil;
  if (@available(iOS 10.0, *)) {
    [audioSession setCategory:AVAudioSessionCategoryPlayback
                         mode:AVAudioSessionModeDefault
                      options:0
                        error:&err];
  } else {
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&err];
  }
  [audioSession
        setActive:NO
      withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
            error:&err];
}

@end
