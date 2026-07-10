/**
 * Metro config for the HarmonyOS JS bundle (RN 0.72.5 + RNOH).
 *
 * Two jobs:
 *  1. Apply the RNOH harmony preset → registers the `harmony` platform + the
 *     `.harmony.js` overrides (this is what fixes the `ReactDevToolsSettingsManager`
 *     / `.android.js`-only resolution failures you hit with the plain config).
 *  2. Resolve the workspace provider packages (react-native-cn-maps[-amap|-baidu|
 *     -tencent], linked via file:) while pinning react / react-native to THIS app's
 *     0.72.5 copy — so the lib never drags in the monorepo root's 0.85.
 *
 * 查证: exact import path + option name of the harmony preset for RNOH 0.72.38
 * (`@react-native-oh/react-native-harmony/metro.config`).
 */
const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const { createHarmonyMetroConfig } = require('@react-native-oh/react-native-harmony/metro.config');

const repoRoot = path.resolve(__dirname, '../..');
const appNodeModules = path.resolve(__dirname, 'node_modules');

module.exports = mergeConfig(
  getDefaultConfig(__dirname),
  createHarmonyMetroConfig({
    reactNativeHarmonyPackageName: '@react-native-oh/react-native-harmony',
  }),
  {
    // Watch the monorepo so file:-linked packages/* resolve + hot-reload.
    watchFolders: [repoRoot],
    resolver: {
      nodeModulesPaths: [appNodeModules],
      // Pin the single react / react-native (0.72.5) the whole graph uses.
      extraNodeModules: {
        'react': path.resolve(appNodeModules, 'react'),
        'react-native': path.resolve(appNodeModules, 'react-native'),
      },
      // Ignore the 0.85 example's / monorepo-root's installed react & react-native
      // so they can't leak into this graph. The lib (packages/*) lives at the repo
      // root, so without blocking `react` it resolves to the root's React 19 (for the
      // 0.85 iOS/Android example) → two copies of React → "Invalid hook call /
      // Cannot read property 'useRef' of null". Pin everything to THIS app's 18.2.0.
      blockList: [
        new RegExp(`${path.resolve(repoRoot, 'example/node_modules/react-native')}/.*`),
        new RegExp(`${path.resolve(repoRoot, 'node_modules/react-native')}/.*`),
        new RegExp(`${path.resolve(repoRoot, 'example/node_modules/react')}/.*`),
        new RegExp(`${path.resolve(repoRoot, 'node_modules/react')}/.*`),
        // provider 包的 harmony/oh_modules 是 ArkTS/native 依赖（各含一份 RNOH 副本），
        // JS 侧不该扫描，否则与 example/harmony/oh_modules 的 hermes-parser 等发生 haste
        // 重复模块冲突 → Metro "Duplicated files or mocks"。装了 @bdmap/* 后触发。
        new RegExp(`${path.resolve(repoRoot, 'packages')}/[^/]+/harmony/oh_modules/.*`),
      ],
    },
  },
);
