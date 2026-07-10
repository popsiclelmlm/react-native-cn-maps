// RN 0.72 uses metro-react-native-babel-preset (not @react-native/babel-preset,
// which is 0.73+). 查证 against the installed 0.72.5 toolchain.
module.exports = {
  presets: ['module:metro-react-native-babel-preset'],
};
