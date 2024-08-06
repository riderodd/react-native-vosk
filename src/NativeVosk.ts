import { TurboModuleRegistry } from 'react-native';
import type { VoskInterface } from './types';

export default TurboModuleRegistry.getEnforcing<VoskInterface>('Vosk');
