module.exports = {
  // 华为 Map Kit provider：鸿蒙自带地图，仅 HarmonyOS 端存在，无 iOS/Android 原生代码。
  // 置 ios/android 为 null，避免 RN CLI 在 iOS/Android 上尝试自动链接本包。
  // 鸿蒙端由 RNOH 手动注册（example 的 RNPackagesFactory + oh-package），不走 RN 自动链接。
  dependency: {
    platforms: {
      ios: null,
      android: null,
    },
  },
};
