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
      .catch((e: any) => console.log(e));
  }, [vosk]);

  const unload = useCallback(() => {
    vosk.unload();
    setReady(false);
  }, [vosk]);

  useEffect(() => {
    const resultEvent = vosk.onResult((res: { data: string }) => {
      console.log('A onResult event has been caught: ' + res.data);
      setResult(res.data);
      setRecognizing(false);
    });

    const finalResultEvent = vosk.onFinalResult((res: { data: string }) => {
      console.log('A onFinalResult event has been caught: ' + res.data);
      setResult(res.data);
      setRecognizing(false);
    });

    return () => {
      resultEvent.remove();
      finalResultEvent.remove();
    };
  }, [vosk]);

  const grammar = ['gauche', 'droite', '[unk]'];
  // const grammar = ['left', 'right', '[unk]'];

  const record = () => {
    if (!ready) return;
    console.log('Starting recognition...');

    setRecognizing(true);

    vosk.start(grammar).catch((e: any) => {
      console.log('Error: ' + e);
    });
  };

  const stop = () => {
    if (!ready) return;
    console.log('Stoping recognition...');

    setRecognizing(false);

    vosk.stop();
  };

  return (
    <View style={styles.container}>
      <Button
        onPress={ready ? unload : load}
        title={ready ? 'Unload model' : 'Load model'}
        color="blue"
      />

      <Button
        onPress={record}
        title="Record"
        disabled={ready === false || recognizing === true}
        color="#841584"
      />

      <Button
        onPress={stop}
        title="Stop"
        disabled={ready === false || recognizing === false}
        color="#841584"
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
