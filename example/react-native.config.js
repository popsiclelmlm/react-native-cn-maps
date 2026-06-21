const path = require('path');

module.exports = {
  project: {
    ios: {
      automaticPodsInstallation: true,
    },
  },
  dependencies: {
    'react-native-cn-maps': {
      root: path.join(__dirname, '..', 'packages', 'core'),
      platforms: {
        // Codegen script incorrectly fails without this
        // So we explicitly specify the platforms with empty object
        ios: {},
        android: {},
      },
    },
    'react-native-cn-maps-amap': {
      root: path.join(__dirname, '..', 'packages', 'amap'),
      platforms: {
        ios: {},
        android: {},
      },
    },
    'react-native-cn-maps-baidu': {
      root: path.join(__dirname, '..', 'packages', 'baidu'),
      // iOS autolink disabled until BaiduMapKit's verified pod version is pinned
      // (the iOS adapter source ships in the package; Android is fully wired).
      platforms: { ios: null, android: {} },
    },
    'react-native-cn-maps-tencent': {
      root: path.join(__dirname, '..', 'packages', 'tencent'),
      // iOS autolink disabled until QMapKit's verified pod version is pinned.
      platforms: { ios: null, android: {} },
    },
  },
};
