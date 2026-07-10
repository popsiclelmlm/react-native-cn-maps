/*
 * 鸿蒙 example 直接复用 android/iOS 的主 demo（example/src/App.tsx），保证三端示例完全一致。
 * Metro 的 watchFolders 已包含仓库根（见 metro.config.js），故可跨目录引用；src/App.tsx 只用
 * 基础 RN 组件 + react-native-cn-maps，RNOH 均支持，无平台分支、无本地资源。
 *
 * 需要纯 RN 冒烟页时，把 index.js 的入口切到 ./App.smoke。
 */
export { default } from '../src/App';
