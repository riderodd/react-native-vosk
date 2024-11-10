import {
  type EventSubscription,
  NativeEventEmitter,
  NativeModules,
  PermissionsAndroid,
  Platform,
} from 'react-native';
import type { VoskInterface, VoskOptions } from './index.d';

const LINKING_ERROR =
  `The package 'react-native-vosk' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

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

const eventEmitter = new NativeEventEmitter(VoskModule);

export default class Vosk {
  // Public functions

  /**
   * Loads the model from specified path
   *
   * @param path - Path of the model.
   *
   * @example
   *   vosk.loadModel('model-fr-fr').then(() => {
   *      setLoaded(true);
   *   });
   */
  loadModel = (path: string) => VoskModule.loadModel(path);

  /**
   * Asks for recording permissions then starts the recognizer.
   *
   * @param options - Optional settings for the recognizer.
   *
   * @example
   *   vosk.start().then(() => console.log("Recognizer started"));
   *
   *   vosk.start({
   *      grammar: ['cool', 'application', '[unk]'],
   *      timeout: 5000,
   *   }).catch(e => console.log(e));
   */
  start = async (options?: VoskOptions) => {
    if (await this.requestRecordPermission()) return VoskModule.start(options);
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

  onResult = (cb: (e: string) => void): EventSubscription => {
    return eventEmitter.addListener('onResult', cb);
  };
  onPartialResult = (cb: (e: string) => void): EventSubscription => {
    return eventEmitter.addListener('onPartialResult', cb);
  };
  onFinalResult = (cb: (e: string) => void): EventSubscription => {
    return eventEmitter.addListener('onFinalResult', cb);
  };
  onError = (cb: (e: any) => void): EventSubscription => {
    return eventEmitter.addListener('onError', cb);
  };
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
