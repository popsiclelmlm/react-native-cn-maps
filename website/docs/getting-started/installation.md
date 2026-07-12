---
id: installation
title: 安装
sidebar_label: 安装
sidebar_position: 1
description: 安装 react-native-cn-maps 核心包与厂商适配器，并了解版本与新架构要求。
---

# 安装

## 前置要求

- **React Native 已启用新架构（Fabric）**。本库不支持旧桥（Paper）。iOS / Android 基于 RN **0.85** 开发并经 CI 验证。
- Node 与包管理器：仓库使用 Yarn，`npm` / `pnpm` 亦可。

## 安装核心包 + 厂商适配器

核心包 `react-native-cn-maps` 是**必装**的，它提供全部组件与 JS 逻辑；具体地图由厂商适配器包提供，**按需安装**：

```sh
# 核心包（必装）+ 高德（默认厂商）
yarn add react-native-cn-maps react-native-cn-maps-amap

# 按需添加其他厂商
yarn add react-native-cn-maps-baidu    # 百度
yarn add react-native-cn-maps-tencent  # 腾讯
yarn add react-native-cn-maps-mapkit   # 华为地图（仅 HarmonyOS）
```

| 包 | 作用 | 原生坐标系 |
|---|---|---|
| `react-native-cn-maps` | 核心：组件、坐标转换、隐私 API | — |
| `react-native-cn-maps-amap` | 高德适配器 | GCJ-02 |
| `react-native-cn-maps-baidu` | 百度适配器 | BD-09 |
| `react-native-cn-maps-tencent` | 腾讯适配器 | GCJ-02 |
| `react-native-cn-maps-mapkit` | 华为 Map Kit（仅 HarmonyOS） | GCJ-02 |

只需装你实际会用到的厂商包——没装的厂商 SDK 不会进入构建产物。

## iOS

```sh
cd ios && pod install
```

各厂商 podspec 已声明对应原生 SDK 依赖，`pod install` 会自动拉取。

:::info Apple Silicon 模拟器
高德 SDK 无 arm64 模拟器切片，Apple Silicon 上跑模拟器需要额外的 `EXCLUDED_ARCHS` 处理。详见[高德原生配置](../native-setup/amap.md#ios)。
:::

## Android

Android 通过 autolinking 自动接入，通常无需手动改 Gradle。少数情况（如覆盖 SDK 版本、`<Heatmap>` 的 Jetifier）见[高德原生配置](../native-setup/amap.md#android)。

## 配置 SDK Key

装完包还**不能直接出图**——每个厂商都需要在原生侧配置 SDK key，并在挂载地图前声明隐私合规。按厂商继续：

- [高德 AMap 原生配置](../native-setup/amap.md)
- [百度 Baidu 原生配置](../native-setup/baidu.md)
- [腾讯 Tencent 原生配置](../native-setup/tencent.md)
- [华为 Map Kit 原生配置](../native-setup/mapkit.md)

配好后回到[快速开始](./quick-start.md)跑通第一张地图。
