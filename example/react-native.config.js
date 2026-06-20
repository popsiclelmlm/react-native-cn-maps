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
  },
};
