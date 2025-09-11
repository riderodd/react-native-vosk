// Root Expo config plugin entry so users can declare simply:
// plugins: [ ["react-native-vosk", { models: [...], iOSMicrophonePermission: "..." }] ]
module.exports = require('./plugin/build/withVosk');
