import {
  NativeEventEmitter,
  NativeModules,
  PermissionsAndroid,
  Platform,
} from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-vosk' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo managed workflow\n';

const VoskModule = NativeModules.Vosk
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
  loadModel = (path: String) => VoskModule.loadModel(path);

  start = (grammar: string[] | null = null) => {
    let onResult: (...args: any[]) => any;
    let onFinalResult: (...args: any[]) => any;
    let onError: (...args: any[]) => any;
    let onTimeout: (...args: any[]) => any;

    const promise = new Promise((resolve, reject) => {
      // Check for permission
      this.requestRecordPermission()
        .then((granted) => {
          if (!granted) return reject('Audio record permission denied');

          // Setup events
          onResult = (e) => resolve(e.data);
          onFinalResult = (e) => resolve(e.data);
          onError = (e) => reject(e.data);
          onTimeout = () => reject('timeout');
          eventEmitter.addListener('onResult', onResult);
          eventEmitter.addListener('onFinalResult', onFinalResult);
          eventEmitter.addListener('onError', onError);
          eventEmitter.addListener('onTimeout', onTimeout);

          // Start recognition
          VoskModule.start(grammar);
        })
        .catch((e) => {
          reject(e);
        });
    }).finally(() => {
      // Clean event listeners
      eventEmitter.removeListener('onResult', onResult);
      eventEmitter.removeListener('onFinalResult', onFinalResult);
      eventEmitter.removeListener('onError', onError);
      eventEmitter.removeListener('onTimeout', onTimeout);
    });

    return promise;
  };

  stop = () => {
    VoskModule.stop();
  };

  // Event listeners builders
  onResult = (onResult: (...args: any[]) => any) => {
    return eventEmitter.addListener('onResult', onResult);
  };
  onFinalResult = (onFinalResult: (...args: any[]) => any) => {
    return eventEmitter.addListener('onFinalResult', onFinalResult);
  };
  onError = (onError: (...args: any[]) => any) => {
    return eventEmitter.addListener('onError', onError);
  };
  onTimeout = (onTimeout: (...args: any[]) => any) => {
    return eventEmitter.addListener('onTimeout', onTimeout);
  };

  // Private functions
  private requestRecordPermission = async () => {
    const granted = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.RECORD_AUDIO
    );
    return granted === PermissionsAndroid.RESULTS.GRANTED;
  };
}
