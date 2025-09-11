import type { ConfigPlugin } from '@expo/config-plugins';
import {
  withInfoPlist,
  withXcodeProject,
  withGradleProperties,
  createRunOncePlugin,
} from '@expo/config-plugins';
import fs from 'fs';
import path from 'path';
import pkg from '../../package.json';

export type VoskPluginProps = {
  models?: string[]; // Relative paths as provided in app.json (e.g., assets/model-fr-fr)
  iOSMicrophonePermission?: string; // NSMicrophoneUsageDescription text
};

const withVosk: ConfigPlugin<VoskPluginProps | void> = (config, props) => {
  const { models = [], iOSMicrophonePermission } = props as VoskPluginProps;

  // iOS: add microphone permission string
  if (iOSMicrophonePermission) {
    withInfoPlist(config, (configMod) => {
      configMod.modResults.NSMicrophoneUsageDescription =
        iOSMicrophonePermission;
      return configMod;
    });
  }

  // iOS: add model folders to Xcode project resources
  if (models.length) {
    withXcodeProject(config, (configMod) => {
      const project = configMod.modResults;
      const iosRoot = configMod.modRequest.platformProjectRoot; // <app>/ios

      models.forEach((relModelPath: string) => {
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
        // Destination inside ios folder (copy folder to keep it under version control if needed)
        const destFolder = path.join(iosRoot, modelFolderName);
        if (!fs.existsSync(destFolder)) {
          fs.cpSync(absSource, destFolder, { recursive: true });
        }

        // Add to Xcode project if not already
        const projectRelative = modelFolderName;
        const fileRef = project.hasFile(projectRelative);
        if (!fileRef) {
          project.addResourceFile(projectRelative, { variantGroup: false });
        }
      });

      return configMod;
    });
  }

  // Android: pass model paths via gradle properties so the library build.gradle can pick them up.
  if (models.length) {
    withGradleProperties(config, (configMod) => {
      const key = 'Vosk_models';
      const value = models.join(',');
      const existingIndex = configMod.modResults.findIndex(
        (p: any) => p.type === 'property' && p.key === key
      );
      if (existingIndex >= 0) {
        const item: any = configMod.modResults[existingIndex];
        item.value = value;
      } else {
        (configMod.modResults as any).push({ type: 'property', key, value });
      }
      return configMod;
    });
  }

  return config;
};

export default createRunOncePlugin(withVosk, pkg.name, pkg.version);
