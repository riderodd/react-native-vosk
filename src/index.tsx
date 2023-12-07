import {
  type EventSubscription,
  NativeEventEmitter,
  NativeModules,
  PermissionsAndroid,
  Platform,
} from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-vosk' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

interface VoskInterface {
  loadModel: (path: string) => Promise<void>;
  unload: () => void;

  start: (grammar: string[] | null) => Promise<void>;
  setGrammar: (grammar: string[] | null) => Promise<void>;
  stop: () => void;

  addListener: (eventType: string) => void;
  removeListeners: (count: number) => void;
}

const VoskModule: VoskInterface = NativeModules.Vosk
  ? NativeModules.Vosk
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

type VoskEvent = {
  /**
   * Event datas
   */
  data: string;
};

const eventEmitter = new NativeEventEmitter();

export default class Vosk {
  // Public functions

  /**
   * Loads the model from specified path
   *
   * @param path - Path of the model.
   *
   * @example
   *   vosk.loadModel('model-fr-fr');
   */
  loadModel = (path: string) => VoskModule.loadModel(path);

  /**
   * Starts the recognizer using desired grammar if specified,
   *   an `onResult()` event will be fired.
   *
   * @param grammar - Optional set of phrases the recognizer will seek on
   *   which is the closest one from the record,
   *   add `"[unk]"` to the set to recognize phrases striclty.
   *
   * @example
   *   vosk.start();
   *   vosk.start(['cool', 'application', '[unk]']);
   */
  start = async (grammar: string[] | null = null) => {
    // Check for permission
    if (await this.requestRecordPermission()) return VoskModule.start(grammar);
  };

  setGrammar = async (grammar: string[] | null = null) => {
    return VoskModule.setGrammar(grammar);
  };

  /**
   * Stops the recognizer. Listener should receive final result if there is any.
   */
  stop = () => VoskModule.stop();

  /**
   * Unloads the model, also stops the recognizer.
   */
  unload = () => VoskModule.unload();

  // Event listeners builders

  onResult = (cb: (e: VoskEvent) => void): EventSubscription => {
    return eventEmitter.addListener('onResult', cb);
  };
  onPartialResult = (cb: (e: VoskEvent) => void): EventSubscription => {
    return eventEmitter.addListener('onPartialResult', cb);
  };
  onFinalResult = (cb: (e: VoskEvent) => void): EventSubscription => {
    return eventEmitter.addListener('onFinalResult', cb);
  };
  onError = (cb: (e: VoskEvent) => void): EventSubscription => {
    return eventEmitter.addListener('onError', cb);
  };

  /**
   * NOT IMPLEMENTED ON ANDROID YET.
   */
  onTimeout = (cb: () => void): EventSubscription => {
    return eventEmitter.addListener('onTimeout', cb);
  };

  // Private functions

  private requestRecordPermission = async () => {
    if (Platform.OS === 'ios') return true;
    const granted = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.RECORD_AUDIO!
    );
    return granted === PermissionsAndroid.RESULTS.GRANTED;
  };
}
