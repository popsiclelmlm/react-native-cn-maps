module.exports = {
  dependency: {
    platforms: {
      // iOS 自动链接默认关闭：百度 iOS 适配器源码随包分发、podspec 已 pin
      // BaiduMapKit ~> 6.6.0，但尚未真机验证。需要 iOS 支持时，在宿主 App 的
      // react-native.config.js 里为本包显式开启 `ios: {}` 并自行验证。
      // Android 已完整接线并验证。
      ios: null,
      android: {},
    },
  },
};
