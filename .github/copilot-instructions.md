# Copilot Coding Agent Onboarding Instructions

## Repository Summary

This repository provides a React Native module for offline speech recognition using the [Vosk](https://github.com/alphacep/vosk-api) library. It supports both Android and iOS platforms, with native code in Kotlin (Android) and Swift/Objective-C++ (iOS). The repo is a monorepo managed with Yarn workspaces, containing the main library and an example app.

- **Languages:** TypeScript, JavaScript, Kotlin, Swift, Objective-C++
- **Frameworks:** React Native, Vosk API
- **Size:** Medium (multiple platforms, native code, models, example app)
- **Package Manager:** Yarn (v3.6.1, enforced)
- **Node Version:** >=18 (see `.nvmrc`)

## Build, Test, and Validation Instructions

### Environment Setup
- Always use **Yarn** (not npm) for dependency management and scripts.
- Ensure Node.js v18+ is active (`nvm use` if needed).
- Run `yarn install --immutable` before any build or test steps.
- For native builds, ensure Android Studio and XCode are installed and configured.

### Bootstrap
- Run `yarn` in the repo root to install all dependencies for both the library and example app.

### Build
- **Library:**
  - Run `yarn prepare` to build the library (uses `react-native-builder-bob`).
- **Android Example:**
  - Run `yarn example android` to build and run the example app on Android.
- **iOS Example:**
  - Run `yarn example ios` to build and run the example app on iOS.

### Test
- Run `yarn test` to execute Jest unit tests.
- Run `yarn typecheck` for TypeScript validation.
- Run `yarn lint` for ESLint checks. Use `yarn lint --fix` to auto-fix issues.

### Clean
- Run `yarn clean` to remove build artifacts from both library and example app.

### Pre-commit & CI
- Pre-commit hooks (via Lefthook) run `eslint` and `tsc` on staged files, and `commitlint` on commit messages.
- CI (GitHub Actions) runs lint, typecheck, test, and build steps on PRs and pushes to `main`.
- Commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/en).

### Publishing
- Releases are managed with `release-it`. To publish, run `yarn release` (requires permissions).

### Android/iOS Model Setup
- Download Vosk models from [official site](https://alphacephei.com/vosk/models).
- For Android, place models in `example/android/app/src/main/assets/model-<lang>/`.
- For iOS, add models to the XCode project (see README for details).

## Project Layout & Key Files
- **Root:**
  - `package.json`, `babel.config.js`, `tsconfig.json`, `lefthook.yml`, `.nvmrc`, `.editorconfig`, `.gitignore`, `.release-it.json`, `react-native-vosk.podspec`
  - `android/`, `ios/`, `src/`, `example/`, `docs/`
- **Library Source:** `src/index.tsx`, `src/index.d.ts`
- **Native Android:** `android/src/main/java/com/vosk/VoskModule.kt`, `VoskPackage.kt`, `AndroidManifest.xml`
- **Native iOS:** `ios/Vosk.swift`, `Vosk.mm`, `VoskModel.swift`, `libvosk.xcframework/`, `vosk-model-spk-0.4/`
- **Example App:** `example/src/App.tsx`, `example/package.json`, `example/android/`, `example/ios/`
- **Tests:** `src/__tests__/index.test.tsx` (add more as needed)
- **CI/CD:** `.github/workflows/ci.yml`, `.github/workflows/npm-publish.yml`, `.github/actions/setup/action.yml`

## Validation Steps
- Always run `yarn lint`, `yarn typecheck`, and `yarn test` before submitting changes.
- For native code changes, rebuild the example app and verify functionality on both platforms.
- Ensure commit messages pass pre-commit hooks.
- Check CI status on PRs before merging.

## Troubleshooting & Workarounds
- If build/test fails, run `yarn clean` then `yarn install` and retry.
- If native code changes are not reflected, rebuild the example app.
- If model loading fails, verify model path and permissions.
- Only use npm for publishing; all other steps must use Yarn.

## Trust These Instructions
- Trust the above instructions for all build, test, and validation steps.
- Only perform additional searches if these instructions are incomplete or found to be in error.

---

For further details, see `README.md` and `CONTRIBUTING.md`.
