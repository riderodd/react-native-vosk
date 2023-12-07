import React, { useState, useEffect, useRef, useCallback } from 'react';

import { StyleSheet, View, Text, Button } from 'react-native';
import Vosk from 'react-native-vosk';

export default function App(): JSX.Element {
  const [ready, setReady] = useState<Boolean>(false);
  const [recognizing, setRecognizing] = useState<Boolean>(false);
  const [result, setResult] = useState<string | undefined>();

  const vosk = useRef(new Vosk()).current;

  const load = useCallback(() => {
    vosk
      .loadModel('model-fr-fr')
      // .loadModel('model-en-us')
      .then(() => setReady(true))
      .catch((e) => console.error(e));
  }, [vosk]);

  const unload = useCallback(() => {
    vosk.unload();
    setReady(false);
    setRecognizing(false);
  }, [vosk]);

  useEffect(() => {
    const resultEvent = vosk.onResult((res) => {
      console.log('An onResult event has been caught: ' + res);
      setResult(res);
    });

    const partialResultEvent = vosk.onPartialResult((res) => {
      setResult(res);
    });

    const errorEvent = vosk.onError((e) => {
      console.error(e);
    });

    const timeoutEvent = vosk.onTimeout(() => {
      console.log('Recognizer timed out');
      setRecognizing(false);
    });

    return () => {
      resultEvent.remove();
      partialResultEvent.remove();
      errorEvent.remove();
      timeoutEvent.remove();
    };
  }, [vosk]);

  const record = () => {
    vosk
      .start({ grammar: ['gauche', 'droite'] })
      .then(() => {
        console.log('Starting recognition...');
        setRecognizing(true);
      })
      .catch((e) => console.error(e));
  };

  const stop = () => {
    vosk.stop();
    console.log('Stoping recognition...');
    setRecognizing(false);
  };

  return (
    <View style={styles.container}>
      <Button
        onPress={ready ? unload : load}
        title={ready ? 'Unload model' : 'Load model'}
        color="blue"
      />

      <Button
        onPress={recognizing ? stop : record}
        title={recognizing ? 'Stop' : 'Record'}
        disabled={ready === false}
        color={recognizing ? 'red' : 'green'}
      />

      <Text>Recognized word:</Text>
      <Text>{result}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: 10,
    flex: 1,
    textAlign: 'center',
    alignItems: 'center',
    justifyContent: 'center',
  },
});
