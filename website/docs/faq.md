---
id: faq
title: 常见问题（FAQ）
sidebar_label: FAQ
sidebar_position: 99
description: react-native-cn-maps 常见问题：地图空白、坐标偏移、切换厂商、平台支持等。
---

# 常见问题

### 地图一片空白怎么办？

最常见的原因有两个，按顺序排查：

1. **没声明隐私合规**：中国地图 SDK 在 `setPrivacyConsent` 之前不初始化。见[隐私合规](./guides/privacy-compliance.md)。
2. **没配 SDK key**：每个厂商都需要在原生侧配 key。见[原生配置](./native-setup/amap.md)。

其次确认 MapView 有明确尺寸（`style={{ flex: 1 }}` 或固定宽高）。

### 标记 / 视野整体偏移几百米？

坐标系填错了。用 `coordinateSystem` 声明**你的坐标来源系**（GPS 数据填 `wgs84`）。见[坐标系专题](./guides/coordinate-systems.md)。

### 能用 Google Maps 吗？

不能。本库定位中国地图厂商，不支持 `provider="google"` 与 Web。需要 Google Maps 请用 [`react-native-maps`](https://github.com/react-native-maps/react-native-maps)。

### 运行时切换地图厂商？

`provider` 挂载后固定，切换需重挂 `<MapView>`——给它设 `key={provider}` 即可。见[选择地图厂商](./getting-started/choosing-provider.md)。

### 支持旧架构（Paper）吗？

不支持。本库仅新架构（Fabric + TurboModule）。iOS / Android 基于 RN 0.85 验证。

### HarmonyOS Next 支持到什么程度？

基于 [RNOH](https://gitee.com/openharmony-sig/ohos_react_native)，**实验性**：核心流程已真机验证，API 与接入方式仍可能调整。四家厂商都有鸿蒙适配。见[支持矩阵](./guides/provider-matrix.md)。

### iOS 上能用百度 / 腾讯吗？

适配器源码随包发布并固定了 pod 版本，但**尚未真机验证**，默认关闭 iOS autolinking。如需尝试，在 `react-native.config.js` 中为该包开启 `ios: {}` 并自行验证。高德 iOS 已验证可用。

### 从 react-native-maps 迁移麻烦吗？

多数只需改一行 import。真正要动的是坐标系声明和隐私合规两步。见[迁移指南](./guides/migrate-from-react-native-maps.md)。

### Apple Silicon 上模拟器构建失败？

高德 SDK 无 arm64 模拟器切片，需在 `Podfile` 的 `post_install` 排除 arm64。见[高德配置](./native-setup/amap.md#apple-silicon-上运行模拟器)。

### 热力图 / 瓦片图层在百度、腾讯上不显示？

目前 Heatmap 与瓦片图层仅高德接通，百度/腾讯为 TODO。见[支持矩阵](./guides/provider-matrix.md)。

### 没找到答案？

到 [GitHub Discussions](https://github.com/popsiclelmlm/react-native-cn-maps/discussions) 提问，或提 [Issue](https://github.com/popsiclelmlm/react-native-cn-maps/issues)。
