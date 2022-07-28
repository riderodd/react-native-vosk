import {
  EmitterSubscription,
  EventSubscription,
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

type VoskEvent = {
  /**
   * Event datas
   */
  data: string;
}

const eventEmitter = new NativeEventEmitter(VoskModule);

export default class Vosk {
  // Public functions
  loadModel = (path: string) => VoskModule.loadModel(path);

  start = (grammar: string[] | null = null) : Promise<String> => {
    const currentRegisteredEvents: EmitterSubscription[] = [];

    return new Promise<String>((resolve, reject) => {
      // Check for permission
      this.requestRecordPermission()
        .then((granted) => {
          if (!granted) return reject('Audio record permission denied');

          // Setup events
          const onResult = (e: VoskEvent) => resolve(e.data);
          const onFinalResult = (e: VoskEvent) => resolve(e.data);
          const onError = (e: VoskEvent) => reject(e.data);
          const onTimeout = () => reject('timeout');
          currentRegisteredEvents.push(eventEmitter.addListener('onResult', onResult));
          currentRegisteredEvents.push(eventEmitter.addListener('onFinalResult', onFinalResult));
          currentRegisteredEvents.push(eventEmitter.addListener('onError', onError));
          currentRegisteredEvents.push(eventEmitter.addListener('onTimeout', onTimeout));

          // Start recognition
          VoskModule.start(grammar);
        })
        .catch((e) => {
          reject(e);
        });
    }).finally(() => {
      // Clean event listeners
      currentRegisteredEvents.forEach(subscription => subscription.remove());
    });
  };

  stop = () => {
    VoskModule.stop();
  };

  // Event listeners builders
  onResult = (onResult: (e: VoskEvent) => void) : EventSubscription => {
    return eventEmitter.addListener('onResult', onResult);
  };
  onFinalResult = (onFinalResult: (e: VoskEvent) => void) : EventSubscription => {
    return eventEmitter.addListener('onFinalResult', onFinalResult);
  };
  onError = (onError: (e: VoskEvent) => void) : EventSubscription => {
    return eventEmitter.addListener('onError', onError);
  };
  onTimeout = (onTimeout: (e: VoskEvent) => void) : EventSubscription => {
    return eventEmitter.addListener('onTimeout', onTimeout);
  };

  // Private functions
  private requestRecordPermission = async () => {
    if (Platform.OS === "ios") return true;
    const granted = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.RECORD_AUDIO!
    );
    return granted === PermissionsAndroid.RESULTS.GRANTED;
  };
}
