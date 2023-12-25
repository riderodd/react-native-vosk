# react-native-vosk - React ASR (Automated Speech Recognition)

Speech recognition module for react native using [Vosk](https://github.com/alphacep/vosk-api) library

## Installation

### Library

```sh
npm install -S react-native-vosk
```

### Models

Vosk uses prebuilt models to perform speech recognition offline. You have to download the model(s) that you need on [Vosk official website](https://alphacephei.com/vosk/models)
Avoid using too heavy models, because the computation time required to load them into your app could lead to bad user experience.
Then, unzip the model in your app folder. If you just need to use the iOS version, put the model folder wherever you want, and import it as described below. If you need both iOS and Android to work, you can avoid to copy the model twice for both projects by importing the model from the Android assets folder in XCode. Just do as follow:

### Android

In Android Studio, open the project manager, right-click on your project folder and go to `New` > `Folder` > `Assets folder`.

![Android Studio assets folder creation](https://raw.githubusercontent.com/riderodd/react-native-vosk/main/docs/android_studio_assets_folder_creation.png)

Then put the model folder inside the assets folder created. In your file tree it should be located in `android\app\src\main\assets`. So, if you downloaded the french model named `model-fr-fr`, you should access the model by going to `android\app\src\main\assets\model-fr-fr`. In Android studio, your project structure should be like that:

![Android Studio final project structure](https://raw.githubusercontent.com/riderodd/react-native-vosk/main/docs/android_studio_project_structure.png)

You can import as many models as you want.

### iOS

In XCode, right-click on your project folder, and click on `"Add files to [your project name]"`.

![XCode add files to project](https://raw.githubusercontent.com/riderodd/react-native-vosk/main/docs/xcode_add_files_to_folder.png)

Then navigate to your model folder. You can navigate to your Android assets folder as mentionned before, and chose your model here. It will avoid to have the model copied twice in your project. If you don't use the Android build, you can just put the model wherever you want, and select it.

![XCode chose model folder](https://raw.githubusercontent.com/riderodd/react-native-vosk/main/docs/xcode_chose_model_folder.png)

That's all. The model folder should appear in your project. When you click on it, your project target should be checked (see below).

![XCode full settings screenshot](https://raw.githubusercontent.com/riderodd/react-native-vosk/main/docs/xcode_full_settings_screenshot.png)

## Usage

```js
import Vosk from 'react-native-vosk';

// ...

const vosk = new Vosk();

vosk
  .loadModel('model-en-en')
  .then(() => {
    const options = {
      grammar: ['left', 'right', '[unk]'],
    };

    vosk
      .start(options)
      .then(() => {
        console.log('Recognizer successfuly started');
      })
      .catch((e) => {
        console.log('Error: ' + e);
      });

    const resultEvent = vosk.onResult((res) => {
      console.log('A onResult event has been caught: ' + res);
    });

    // Don't forget to call resultEvent.remove(); to delete the listener
  })
  .catch((e) => {
    console.error(e);
  });
```

Note that `start()` method will ask for audio record permission.

[See complete example...](https://github.com/riderodd/react-native-vosk/blob/main/example/src/App.tsx)

### Methods

| Method | Argument | Return | Description |
|---|---|---|---|
| `loadModel` | `path: string` | `Promise<void>` | Loads the voice model used for recognition, it is required before using start method. |
| `start` | `options: VoskOptions` or `none` | `Promise<void>` | Starts the recognizer, an `onResult()` event will be fired. |
| `stop` | `none` | `none` | Stops the recognizer. Listener should receive final result if there is any. |
| `unload` | `none` | `none` | Unloads the model, also stops the recognizer. |

### Types

| VoskOptions | Type | Required | Description |
|---|---|---|---|
| `grammar` | `string[]` | No | Set of phrases the recognizer will seek on which is the closest one from the record, add `"[unk]"` to the set to recognize phrases striclty. |
| `timeout` | `int` | No | Timeout in milliseconds to listen. |

### Events

| Method | Promise return | Description |
|---|---|---|
| `onPartialResult` | The recognized word as a `string` | Called when partial recognition result is available.|
| `onResult` | The recognized word as a `string` | Called after silence occured. |
| `onFinalResult` | The recognized word as a `string` | Called after stream end, like a `stop()` call |
| `onError` | The error that occured as a `string` or `exception` | Called when an error occurs |
| `onTimeout` | `void` | Called after timeout expired |

### Examples

#### Default

```js
vosk.start().then(() => {
  const resultEvent = vosk.onResult((res) => {
    console.log('A onResult event has been caught: ' + res);
  });
});

// when done, remember to call resultEvent.remove();
```

#### Using grammar

```js
vosk.start({
  grammar: ['left', 'right', '[unk]'],
}).then(() => {
  const resultEvent = vosk.onResult((res) => {
    if (res === 'left') {
      console.log('Go left');
    } else if (res === 'right') {
      console.log('Go right');
    } else {
      console.log("Instruction couldn't be recognized");
    }
  });
});

// when done, remember to call resultEvent.remove();
```

#### Using timeout

```js
vosk.start({
  timeout: 5000,
}).then(() => {
  const resultEvent = vosk.onResult((res) => {
    console.log('An onResult event has been caught: ' + res);
  });

  const timeoutEvent = vosk.onTimeout(() => {
    console.log('Recognizer timed out');
  });
})

// when done, remember to clean all listeners;
```

#### [Complete example](https://github.com/riderodd/react-native-vosk/blob/main/example/src/App.tsx)

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT
