import Foundation
import AVFoundation

// The representation of the JSON object returned by Vosk
struct VoskResult: Codable {
    // Partial result
    var partial: String?
    // Complete result
    var text: String?
}

// Structure of options for start method
struct VoskStartOptions {
    // Grammar to use
    var grammar: [String]?
    // Timeout in milliseconds
    var timeout: Int?
}
extension VoskStartOptions: Codable {
    init(dictionary: [String: Any]) throws {
        self = try JSONDecoder().decode(VoskStartOptions.self, from: JSONSerialization.data(withJSONObject: dictionary))
    }
    private enum CodingKeys: String, CodingKey {
        case grammar, timeout
    }
}

@objc(Vosk)
class Vosk: RCTEventEmitter {
    // Class properties
    /// The current vosk model loaded
    var currentModel: VoskModel?
    /// The vosk recognizer
    var recognizer : OpaquePointer?
    /// The audioEngine used to pipe microphone to recognizer
    let audioEngine = AVAudioEngine()
    /// The audioEngine input
    var inputNode: AVAudioInputNode!
    /// The microphone input format
    var formatInput: AVAudioFormat!
    /// A queue to process datas
    var processingQueue: DispatchQueue!
    /// Keep the last processed result here
    var lastRecognizedResult: VoskResult?
    /// The timeout timer ref
    var timeoutTimer: Timer?
    /// The current grammar set
    var grammar: [String]?

    /// React member: has any JS event listener
    var hasListener: Bool = false

    // Class methods
    override init() {
        super.init()
        // Init the processing queue
        processingQueue = DispatchQueue(label: "recognizerQueue")
        // Create a new audio engine.
        inputNode = audioEngine.inputNode
        // Get the microphone default input format
        formatInput = inputNode.inputFormat(forBus: 0)
    }

    deinit {
        // free the recognizer
        vosk_recognizer_free(recognizer);
    }

    /// Called when React adds an event observer
    override func startObserving() {
        hasListener = true
    }

    /// Called when no more event observers are running
    override func stopObserving() {
        hasListener = false
    }

    /// React method to define allowed events
    @objc override func supportedEvents() -> [String]! {
        return ["onError","onResult","onFinalResult","onPartialResult","onTimeout"];
    }

    /// Load a Vosk model
    @objc(loadModel:withResolver:withRejecter:)
    func loadModel(name: String, resolve:RCTPromiseResolveBlock, reject:RCTPromiseRejectBlock) -> Void {
        if (currentModel != nil) {
            currentModel = nil; // deinit model
        }

        // Load the model in a try catch block
        do {
            try currentModel = VoskModel(name: name)
            resolve(true);
        } catch {
            reject(nil, nil, nil);
        }
    }

    /// Start speech recognition
    @objc(start:withResolver:withRejecter:)
    func start(rawOptions: [String : Any]?, resolve:RCTPromiseResolveBlock, reject:RCTPromiseRejectBlock) -> Void {
        let audioSession = AVAudioSession.sharedInstance()

        var options : VoskStartOptions? = nil;
        do {
            options = (rawOptions != nil) ? try VoskStartOptions(dictionary: rawOptions!) : nil
        } catch {
            print(error)
        }

        // if grammar is set in options, override the current grammar
        var grammar: [String]? = nil
        if (options?.grammar != nil && options?.grammar!.isEmpty == false) {
            grammar = options?.grammar
        }

        // if timeout is set in options, handle it
        var timeout: Int? = nil
        if (options?.timeout != nil) {
            timeout = options?.timeout
        }

        do {
            // Ask the user for permission to use the mic if required then start the engine.
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            if (grammar != nil && grammar!.isEmpty == false) {
                let jsonGrammar = try! JSONEncoder().encode(grammar);
                recognizer = vosk_recognizer_new_grm(currentModel!.model, Float(formatInput.sampleRate), String(data: jsonGrammar, encoding: .utf8))
            } else {
                recognizer = vosk_recognizer_new(currentModel!.model, Float(formatInput.sampleRate))
            }

            let formatPcm = AVAudioFormat.init(commonFormat: AVAudioCommonFormat.pcmFormatInt16, sampleRate: formatInput.sampleRate, channels: 1, interleaved: true)

            inputNode.installTap(onBus: 0,
                                 bufferSize: UInt32(formatInput.sampleRate / 10),
                                 format: formatPcm) { buffer, time in
                self.processingQueue.async {
                    let res = self.recognizeData(buffer: buffer)
                    DispatchQueue.main.async {
                        let parsedResult = try! JSONDecoder().decode(VoskResult.self, from: res.result!.data(using: .utf8)!)
                        if (res.completed && self.hasListener && res.result != nil) {
                            self.sendEvent(withName: "onResult", body: parsedResult.text!)
                        } else if (!res.completed && self.hasListener && res.result != nil) {
                            // check if partial result is different from last one
                            if (self.lastRecognizedResult == nil || self.lastRecognizedResult!.partial != parsedResult.partial && !parsedResult.partial!.isEmpty) {
                                self.sendEvent(withName: "onPartialResult", body: parsedResult.partial)
                            }
                        }
                        self.lastRecognizedResult = parsedResult
                    }
                }
            }

            // Start the stream of audio data.
            audioEngine.prepare()

            audioSession.requestRecordPermission { [weak self] success in
                guard success, let self = self else { return }
                try? self.audioEngine.start()
            }

            // and manage timeout if set in options
            if (timeout != nil) {
                // Run timer on main thread
                DispatchQueue.main.async {
                    self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: Double(timeout!) / 1000, repeats: false) {_ in
                        self.processingQueue.async {
                            // and exit on the process queue
                            self.stopInternal(withoutEvents: true)
                            self.sendEvent(withName: "onTimeout", body: "")
                        }
                    }
                }
            }

            resolve("Recognizer successfully started");
        } catch {
            if (hasListener) {
                sendEvent(withName: "onError", body: "Unable to start AVAudioEngine " + error.localizedDescription)
            } else {
                debugPrint("Unable to start AVAudioEngine " + error.localizedDescription)
            }
            vosk_recognizer_free(recognizer);
            reject("start", error.localizedDescription, error);
        }
    }

    /// Unload speech recognition and model
    @objc(unload) func unload() -> Void {
        stopInternal(withoutEvents: false)
        if (currentModel != nil) {
            currentModel = nil; // deinit model
        }
    }

    /// Stop speech recognition if started
    @objc(stop) func stop() -> Void {
        // stop engines and send onFinalResult event
        stopInternal(withoutEvents: false)
    }

    /// Do internal cleanup on stop recognition
    func stopInternal(withoutEvents: Bool) {
        inputNode.removeTap(onBus: 0)
        if (audioEngine.isRunning) {
            audioEngine.stop()
            if (hasListener && !withoutEvents) {
                sendEvent(withName: "onFinalResult", body: lastRecognizedResult!.partial)
            }
            lastRecognizedResult = nil
        }
        if (recognizer != nil) {
            vosk_recognizer_free(recognizer);
            recognizer = nil
        }
        if (timeoutTimer != nil) {
            timeoutTimer?.invalidate()
            timeoutTimer = nil
        }
    }

    /// Process the audio buffer and do recognition with Vosk
    func recognizeData(buffer : AVAudioPCMBuffer) -> (result: String?, completed: Bool) {
        let dataLen = Int(buffer.frameLength * 2)
        let channels = UnsafeBufferPointer(start: buffer.int16ChannelData, count: 1)
        let endOfSpeech = channels[0].withMemoryRebound(to: Int8.self, capacity: dataLen) {
            return vosk_recognizer_accept_waveform(recognizer, $0, Int32(dataLen))
        }
        let res = endOfSpeech == 1 ?
        vosk_recognizer_result(recognizer) :
        vosk_recognizer_partial_result(recognizer)
        return (String(validatingUTF8: res!), endOfSpeech == 1);
    }
}
