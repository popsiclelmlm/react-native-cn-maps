---
id: mapkit
title: 华为 Map Kit 原生配置
sidebar_label: 华为 Map Kit
description: 在 HarmonyOS Next 上使用华为 Map Kit（鸿蒙系统地图），走 AppGallery Connect 鉴权、无需下载 SDK。
---

# 华为 Map Kit 原生配置

华为 Map Kit（华为地图 / 鸿蒙系统自带地图），**仅 HarmonyOS Next 可用**——iOS/Android 上没有实现（那两端请用 `amap` / `baidu` / `tencent`）。原生坐标系 **GCJ-02**。

## 安装与选择

```sh
yarn add react-native-cn-maps react-native-cn-maps-mapkit
```

```tsx
<MapView provider="mapkit" />
```

## 原生配置（HarmonyOS）

Map Kit 是**系统 Kit**（`@kit.MapKit`）——无需下载 SDK，也无需在 `oh-package.json5` 添加地图依赖。

鉴权走 AppGallery Connect（AGC），而非代码内 API key：

1. 在 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html) 创建应用并开启 **Map Kit**。
2. 在宿主模块的 `module.json5` 中声明 `client_id`：

```json5 title="entry/src/main/module.json5"
{
  "module": {
    "metadata": [
      { "name": "client_id", "value": "<YOUR_AGC_CLIENT_ID>" }
    ]
  }
}
```

:::info HarmonyOS 5.0.2 (API 14)+
从 HarmonyOS 5.0.2 起 `client_id` metadata 不再必需——系统自动鉴权。
:::

## 隐私合规

Map Kit 是系统地图，**无需** `setApiKey`，也无需隐私合规初始化。从 `react-native-cn-maps` 调用 `setPrivacyConsent()` 也没问题——对 Map Kit 是空操作，而其他厂商本来就需要它。

## 状态

> <IconFlask /> **实验性**，与本库全部 HarmonyOS 支持一致（基于 RNOH）。

- 仅 HarmonyOS：autolinking 不暴露任何 iOS/Android 代码（设计如此）。
- 能力面遵循共享适配器契约，完整对照见[厂商支持矩阵](../guides/provider-matrix.md)。
