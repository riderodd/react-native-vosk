// Expo config plugin for react-native-vosk
// Usage in app.json / app.config.js:
// {
//   plugins: [
//     ["react-native-vosk", {
//        models: ["assets/model-fr-fr", "assets/model-en-en"],
//        iOSMicrophonePermission: "Nous avons besoin d'accéder à votre microphone"
//     }]
//   ]
// }

const {
  withInfoPlist,
  withXcodeProject,
  withGradleProperties,
  createRunOncePlugin,
} = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

const pkg = require('../package.json');

/**
 * @typedef {Object} VoskPluginProps
 * @property {string[]} [models] Relative paths (from project root) to model folders to bundle.
 * @property {string} [iOSMicrophonePermission] String for NSMicrophoneUsageDescription.
 */

/** @type {import('@expo/config-plugins').ConfigPlugin<VoskPluginProps>} */
const withVosk = (config, props = {}) => {
  const { models = [], iOSMicrophonePermission } = props;

  // iOS permission
  if (iOSMicrophonePermission) {
    withInfoPlist(config, (configMod) => {
      configMod.modResults.NSMicrophoneUsageDescription =
        iOSMicrophonePermission ||
        configMod.modResults.NSMicrophoneUsageDescription ||
        'Microphone access is required for speech recognition';
      return configMod;
    });
  }

  // iOS models: copy folders into ios project root and add to Xcode resources.
  if (models.length) {
    withXcodeProject(config, (configMod) => {
      const project = configMod.modResults;
      const iosRoot = configMod.modRequest.platformProjectRoot;
      models.forEach((relModelPath) => {
        const absSource = path.join(
          configMod.modRequest.projectRoot,
          relModelPath
        );
        if (!fs.existsSync(absSource)) {
          console.warn(
            '[react-native-vosk] iOS model path not found: ' + absSource
          );
          return;
        }
        const modelFolderName = path.basename(absSource);
        const destFolder = path.join(iosRoot, modelFolderName);
        if (!fs.existsSync(destFolder)) {
          fs.cpSync(absSource, destFolder, { recursive: true });
        }
        if (!project.hasFile(modelFolderName)) {
          project.addResourceFile(modelFolderName, { variantGroup: false });
        }
      });
      return configMod;
    });
  }

  // Android: write Gradle property so library build.gradle picks models up.
  if (models.length) {
    withGradleProperties(config, (configMod) => {
      const key = 'Vosk_models';
      const value = models.join(',');
      const existing = configMod.modResults.find(
        (p) => p.type === 'property' && p.key === key
      );
      if (existing) existing.value = value;
      else configMod.modResults.push({ type: 'property', key, value });
      return configMod;
    });
  }

  return config;
};

// Ensure plugin runs once with a stable name
module.exports = createRunOncePlugin(withVosk, pkg.name, pkg.version);
module.exports.withVosk = withVosk;
