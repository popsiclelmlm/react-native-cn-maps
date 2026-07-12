---
id: intro
title: 介绍
sidebar_label: 介绍
sidebar_position: 1
slug: /
description: react-native-cn-maps 是兼容 react-native-maps API 的中国地图 React Native 组件库，支持高德、百度、腾讯、华为地图，覆盖 iOS / Android / HarmonyOS Next。
---

# react-native-cn-maps

兼容 [`react-native-maps`](https://github.com/react-native-maps/react-native-maps) API 的**中国地图** React Native 组件库。

> 高德 · 百度 · 腾讯 · 华为地图 ｜ iOS · Android · HarmonyOS Next ｜ 新架构 (Fabric)

## 为什么用它

`react-native-maps` 在中国大陆有两个硬伤：Google Maps 不可用，且不处理国内的坐标系加偏（GCJ-02 / BD-09）。本库用一套**对齐 `react-native-maps` 的 API**，底层接高德 / 百度 / 腾讯 / 华为的原生 SDK，并在 JS 层自动完成坐标系转换。

- **API 对齐**：13 个组件全量覆盖，从 `react-native-maps` 迁移多数只需改一行 import，真正的差异点是坐标系。见[迁移指南](./guides/migrate-from-react-native-maps.md)。
- **多厂商、按需安装**：核心包与厂商适配器分离，各厂商独立发包，不会把用不到的地图 SDK 打进应用。见[选择地图厂商](./getting-started/choosing-provider.md)。
- **坐标系自动转换**：声明输入坐标系（`wgs84` / `gcj02` / `bd09`），库转换为所选厂商的原生系。见[坐标系专题](./guides/coordinate-systems.md)。
- **仅支持新架构**：Fabric 组件 + TurboModule，无旧桥。
- **隐私合规优先**：库绝不代为同意隐私政策，由宿主应用显式声明。见[隐私合规](./guides/privacy-compliance.md)。

## 30 秒上手

```sh
yarn add react-native-cn-maps react-native-cn-maps-amap
```

```tsx
import MapView, { Marker } from 'react-native-cn-maps';

export default function Map() {
  return (
    <MapView
      provider="amap"
      coordinateSystem="gcj02"
      style={{ flex: 1 }}
      initialRegion={{
        latitude: 31.2304,
        longitude: 121.4737,
        latitudeDelta: 0.05,
        longitudeDelta: 0.05,
      }}
    >
      <Marker coordinate={{ latitude: 31.2304, longitude: 121.4737 }} title="上海" />
    </MapView>
  );
}
```

:::warning 地图空白？
中国地图 SDK 在宿主应用**声明隐私合规之前**不会初始化，地图渲染为空白。这是预期行为，务必先读[隐私合规（必读）](./guides/privacy-compliance.md)。
:::

## 下一步

| 我想…… | 去这里 |
|---|---|
| 装好依赖、配好原生 key | [安装](./getting-started/installation.md) → [原生配置](./native-setup/amap.md) |
| 跑通第一张地图 | [快速开始](./getting-started/quick-start.md) |
| 选高德还是百度/腾讯 | [选择地图厂商](./getting-started/choosing-provider.md) |
| 从 react-native-maps 搬过来 | [迁移指南](./guides/migrate-from-react-native-maps.md) |
| 查某个组件的 props/事件/方法 | [API 参考](./api/index.md) |
| 搞懂坐标偏移 | [坐标系专题](./guides/coordinate-systems.md) |

## 支持范围

- **平台**：iOS、Android、HarmonyOS Next（RNOH，实验性）。不支持 `provider="google"` 与 Web，本库定位中国地图厂商。
- **React Native**：iOS / Android 基于 **0.85** 开发并经 CI 验证，仅新架构（Fabric），不支持旧桥；HarmonyOS Next 基于 RNOH（RN 0.72），实验性。

详见[厂商支持矩阵](./guides/provider-matrix.md)。
