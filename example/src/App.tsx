import React, { useState, useEffect, useRef, useCallback } from 'react';

import { StyleSheet, View, Text, Button, Switch } from 'react-native';
import Vosk from 'react-native-vosk';
import { FileSystem, Dirs } from 'react-native-file-access';

export default function App(): JSX.Element {
  const [ready, setReady] = useState<boolean>(false);
  const [recognizing, setRecognizing] = useState<Boolean>(false);
  const [result, setResult] = useState<string | undefined>();
  const [modelSource, setModelSource] = useState<'local' | 'dist'>('local');

  const vosk = useRef(new Vosk()).current;

  const load = useCallback(() => {
    if (modelSource === 'local') {
      vosk
        .loadModel('model-fr-fr')
        // .loadModel('model-en-us')
        .then(() => setReady(true))
        .catch((e) => console.error(e));
    } else {
      const path = `${Dirs.CacheDir}/vosk-model`;
      FileSystem.fetch(
        'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip',
        { path }
      ).then((res) => {
        if (res.status !== 200) {
          console.error('Failed to download model');
          return;
        }
        console.log('Model downloaded');
        const unzippedPathWithRandomId = `${
          Dirs.CacheDir
        }/vosk-model-unzipped-${Math.floor(Math.random() * 1000)}`;
        FileSystem.unzip(path, unzippedPathWithRandomId).then(() => {
          console.log('Model unzipped');
          const unzippedPath = `${unzippedPathWithRandomId}/vosk-model-small-en-us-0.15`;
          FileSystem.ls(unzippedPath).then((files) => {
            console.log(files);
          });
          FileSystem.unlink(path); // remove zip file
          vosk
            .loadModel(unzippedPath)
            .then(() => setReady(true))
            .catch((e) => console.error(e));
        });
      });
    }
  }, [vosk, modelSource]);

  const record = () => {
    vosk
      .start()
      .then(() => {
        console.log('Starting recognition...');
        setRecognizing(true);
      })
      .catch((e) => console.error(e));
  };

  const recordGrammar = () => {
    vosk
      .start({ grammar: ['cool', 'application', '[unk]'] })
      .then(() => {
        console.log('Starting recognition with grammar...');
        setRecognizing(true);
      })
      .catch((e) => console.error(e));
  };

  const recordTimeout = () => {
    vosk
      .start({ timeout: 5000 })
      .then(() => {
        console.log('Starting recognition with timeout...');
        setRecognizing(true);
      })
      .catch((e) => console.error(e));
  };

  const stop = () => {
    vosk.stop();
    console.log('Stoping recognition...');
    setRecognizing(false);
  };

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

    const finalResultEvent = vosk.onFinalResult((res) => {
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
      finalResultEvent.remove();
      errorEvent.remove();
      timeoutEvent.remove();
    };
  }, [vosk]);

  return (
    <View style={styles.container}>
      <Button
        onPress={ready ? unload : load}
        title={ready ? 'Unload model' : 'Load model'}
        color="blue"
      />

      {!recognizing && (
        <View style={styles.recordingButtons}>
          <View>
            <Text>Model source:</Text>
            <Text>{modelSource === 'local' ? 'Local' : 'URL'}</Text>
            <Switch
              value={modelSource === 'dist'}
              onValueChange={(value) =>
                setModelSource(value ? 'dist' : 'local')
              }
              disabled={ready}
            />
          </View>

          <Button
            title="Record"
            onPress={record}
            disabled={!ready}
            color="green"
          />

          <Button
            title="Record with grammar"
            onPress={recordGrammar}
            disabled={!ready}
            color="green"
          />

          <Button
            title="Record with timeout"
            onPress={recordTimeout}
            disabled={!ready}
            color="green"
          />
        </View>
      )}

      {recognizing && <Button onPress={stop} title="Stop" color="red" />}

      <Text>Recognized word:</Text>
      <Text>{result}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: 25,
    flex: 1,
    display: 'flex',
    textAlign: 'center',
    alignItems: 'center',
    justifyContent: 'center',
  },
  recordingButtons: {
    gap: 15,
    display: 'flex',
  },
});
