import { PermissionsAndroid, Platform } from 'react-native';
import Vosk, { type VoskOptions } from './NativeVosk';

/**
 * Loads the model from specified path
 *
 * @param path - Path of the model.
 * @returns A promise that resolves when the model is loaded
 * @example
 *   loadModel('model-fr-fr').then(() => {
 *      setLoaded(true);
 *   });
 */
export function loadModel(path: string) {
  return Vosk.loadModel(path);
}

/**
 * Unloads the model, also stops the recognizer.
 *
 * @example
 *   unload().then(() => {
 *      setLoaded(false);
 *   });
 * @returns A promise that resolves when the model is unloaded
 */
export function unload() {
  return Vosk.unload();
}

/**
 * Requests record permission on Android.
 *
 * @returns true if permission is granted, false otherwise
 * @private
 */
async function requestRecordPermission() {
  if (Platform.OS === 'ios') return true;
  const granted = await PermissionsAndroid.request(
    PermissionsAndroid.PERMISSIONS.RECORD_AUDIO!
  );
  return granted === PermissionsAndroid.RESULTS.GRANTED;
}

/**
 * Asks for recording permissions then starts the recognizer.
 *
 * @param options - Optional settings for the recognizer.
 * @returns A promise that resolves when the recognizer has started
 * @example
 *   start().then(() => console.log("Recognizer started"));
 *
 *   start({
 *      grammar: ['cool', 'application', '[unk]'],
 *      timeout: 5000,
 *   }).catch(e => console.log(e));
 */
export function start(options?: VoskOptions) {
  return requestRecordPermission().then((granted) => {
    if (granted) return Vosk.start(options);
    return Promise.reject('Record permission not granted');
  });
}

/**
 * Stops the recognizer. Listener should receive final result if there is any.
 *
 * @example
 *   stop();
 * @returns void
 */
export function stop() {
  return Vosk.stop();
}

/**
 * Event listener for error event
 *
 * @param cb - Callback to be called on error event
 * @returns A subscription to the event
 */
export function onError(cb: (e: any) => void) {
  return Vosk.onError(cb);
}

/** Event listener for timeout event
 *
 * @param cb - Callback to be called on timeout event
 * @returns A subscription to the event
 */
export function onTimeout(cb: () => void) {
  return Vosk.onTimeout(cb);
}

/** Event listener for partial result event
 *
 * @param cb - Callback to be called on partial result event
 * @returns A subscription to the event
 */
export function onPartialResult(cb: (e: string) => void) {
  return Vosk.onPartialResult(cb);
}

/** Event listener for final result event
 *
 * @param cb - Callback to be called on final result event
 * @returns A subscription to the event
 */
export function onFinalResult(cb: (e: string) => void) {
  return Vosk.onFinalResult(cb);
}

/** Event listener for result event
 *
 * @param cb - Callback to be called on result event
 * @returns A subscription to the event
 */
export function onResult(cb: (e: string) => void) {
  return Vosk.onResult(cb);
}
