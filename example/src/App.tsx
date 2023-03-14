import React, { useState, useEffect, useRef } from 'react';

import { StyleSheet, View, Text, Button } from 'react-native';
import Vosk from 'react-native-vosk';

export default function App(): JSX.Element {
  const [ready, setReady] = useState<Boolean>(true);
  const [result, setResult] = useState<String | undefined>();

  const vosk = useRef(new Vosk()).current;

  useEffect(() => {
    vosk
      .loadModel('model-fr-fr')
      // .loadModel('model-en-us')
      .then(() => setReady(true))
      .catch((e: any) => console.log(e));

    const resultEvent = vosk.onResult((res: any) => {
      console.log('A onResult event has been caught: ' + res.data);
    });

    return () => {
      resultEvent.remove();
      vosk.unload();
    };
  }, [vosk]);

  const grammar = ['gauche', 'droite', '[unk]'];
  // const grammar = ['left', 'right', '[unk]'];

  const record = () => {
    console.log('Starting recognition...');

    setReady(false);

    vosk
      .start(grammar)
      .then((res: string) => {
        console.log('Result is: ' + res);
        setResult(res);
      })
      .catch((e: any) => {
        console.log('Error: ' + e);
      })
      .finally(() => {
        setReady(true);
      });
  };

  return (
    <View style={styles.container}>
      <Button
        onPress={record}
        title="Record"
        disabled={!ready}
        color="#841584"
      />
      <Text>Recognized word:</Text>
      <Text>{result}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
