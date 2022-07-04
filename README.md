# react-native-vosk

Voice recognition module for react native using [Vosk](https://github.com/alphacep/vosk-api) library

## Installation

```sh
npm install react-native-vosk
```

In your app change `minSdkVersion` to at least 21

```gradle
buildscript {
    ext {
        minSdkVersion = 21
        ...
    }
    ...
}
```

## Usage

```js
import VoiceRecognition from 'react-native-voice-recognition';

// ...

const voiceRecognition = new VoiceRecognition();

voiceRecognition.loadModel('model-fr-fr');
voiceRecognition
    .start()
    .then((res: any) => {
        console.log('Result is: ' + res);
    })
```

Note that `start()` method will ask for audio record permission.

[Complete example...](https://github.com/riderodd/react-native-vosk/blob/main/example/src/App.tsx)

### Methods

| Method | Argument | Return | Description |
|---|---|---|---|
| `loadModel` | `path: string` | `Promise` | Loads the voice model used for recognition, it is required before using start method |
| `start` | `grammar: string[]` or `none` | `Promise` | Starts the voice recognition and returns the recognized text as a promised string, you can recognize specific words using the `grammar` argument (ex: ["left", "right"]) according to kaldi's documentation |
| `stop` | `none` | `none` | Stops the recognition |

### Events 

| Method | Promise return | Description |
|---|---|---|
| `onResult` | The recognized word as a `string` | Triggers on voice recognition result |
| `onFinalResult` | The recognized word as a `string` | Triggers if stopped using `stop()` method |
| `onError` | The error that occured as a `string` or `exception` | Triggers if an error occured |
| `onTimeout` | "timeout" `string` | Triggers on timeout |

#### Example

```js
const resultEvent = voiceRecognition.onResult((res) => {
    console.log('A onResult event has been caught: ' + res.data);
});
    
resultEvent.remove();
```

Don't forget to remove the event listener once you don't need it anymore.

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT
