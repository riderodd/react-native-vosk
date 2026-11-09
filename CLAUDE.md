# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`AGENTS.md` is a symlink to this file, so edits here apply to every agent.

## Project

`react-native-vosk`: offline speech recognition for React Native, wrapping the [Vosk](https://github.com/alphacep/vosk-api) library. It is a TurboModule (new architecture only) with native code in Kotlin (Android) and Objective-C++ (iOS), plus an Expo config plugin. Yarn workspaces monorepo: the library at the root, the demo app in `example/`.

## Commands

Use Yarn (v3, via `packageManager`), never npm. Node version is in `.nvmrc`.

```sh
yarn                      # install root + example
yarn lint                 # ESLint + Prettier (yarn lint --fix to autofix)
yarn typecheck            # tsc
yarn test                 # Jest; single test: yarn test src/__tests__/index.test.tsx -t "<name>"
yarn prepare              # build lib/ with bob + compile the Expo plugin to plugin/build
yarn clean                # remove lib/ and native build dirs
yarn example start        # Metro for the example app
yarn example android      # build/run example on Android
yarn example ios          # build/run example on iOS
```

Unit tests are essentially placeholders; native changes must be verified by running the example app on each platform. CI (`.github/workflows/ci.yml`) runs lint, typecheck, test, `yarn prepare`, and example builds for Android and iOS.

Commits must follow Conventional Commits (enforced by commitlint via lefthook). Releases use `release-it` (`yarn release`), which writes `CHANGELOG.md`; npm publishing happens in CI with trusted publishing.

## Architecture

**JS layer** (`src/`)
- `NativeVosk.ts` is the codegen spec (`codegenConfig.name = VoskSpec`). It defines `VoskOptions` and the `Spec` interface, including events declared as `CodegenTypes.EventEmitter`. Any API change starts here, then both native modules must be updated to match the generated spec (`NativeVoskSpec` on Android, `JS::NativeVosk::*` types on iOS).
- `index.ts` is the public API: thin wrappers around the native module. `start()` requests `RECORD_AUDIO` on Android before calling native; iOS relies on the system prompt.

**Android** (`android/src/main/java/com/vosk/VoskModule.kt`)
- Uses `com.alphacephei:vosk-android` (`Model`, `Recognizer`, `SpeechService`). `loadModel` first tries the path as a filesystem directory, then falls back to `StorageService.unpack` from app assets.
- Models get into assets through `android/build.gradle`: it copies model folders into `build/generated/assets` and writes a `uuid` file per model (required by `StorageService`). Sources come from the `Vosk_models` Gradle property (set by the Expo plugin) or, as a fallback, by scanning the app's `assets/` folder for `model-*` directories.

**iOS** (`ios/`)
- `Vosk.mm` talks to the Vosk C API (`Vosk-API.h`, vendored `libvosk.xcframework`) and captures audio with `AVAudioEngine`. Recognition runs on a serial `_processingQueue`; events are emitted from the main queue. Tap installation retries until the input format stabilizes. `stopInternalWithoutEvents:` handles teardown without deadlocking when already on the processing queue.
- `RNVoskModel.mm` loads the model from the given path, then from the main bundle, and also loads the bundled speaker model `vosk-model-spk-0.4`.
- `manageAudioSession` (default `true`) controls whether the module sets `AVAudioSession` to record on start and back to playback on stop; `false` lets the host app own the session.

**Platform event differences:** Android emits `onFinalResult` from Vosk's final hypothesis on stop; iOS emits the last partial as `onFinalResult` on stop and de-duplicates partials. Keep both behaviors in mind when touching event semantics.

**Expo plugin** (`plugin/src/withVosk.ts`, entry `app.plugin.js` → `plugin/build`): adds `NSMicrophoneUsageDescription`, adds model folders to the Xcode project resources, and sets the `Vosk_models` Gradle property consumed by `android/build.gradle`.

**Example app** (`example/`): uses the local library source; JS changes hot-reload, native changes need a rebuild. Models live in `example/assets/`.

## Notes

- `.github/copilot-instructions.md` references files that no longer exist (`ios/Vosk.swift`, `src/index.tsx`); trust the code over it.
