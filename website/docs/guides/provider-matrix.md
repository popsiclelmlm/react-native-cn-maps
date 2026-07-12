---
id: provider-matrix
title: 厂商支持矩阵
sidebar_label: 厂商支持矩阵
description: 各厂商 × 平台的支持情况，以及每个组件能力在高德/百度/腾讯/华为上的可用性。
---

# 厂商支持矩阵

:::info 本页正在建设中
细到「每个 prop / 方法 × 厂商 × 平台」的完整矩阵，依赖 iOS 侧的行为一致性验证——而这被**三家厂商 iOS key 的申请**阻塞（见 [ROADMAP](https://github.com/popsiclelmlm/react-native-cn-maps/blob/main/docs/ROADMAP.md) Phase 1）。本页先给出**平台级**与**组件级**的已知支持情况，逐项细化会随验证推进补齐。规划中的最终形态是由一份 JSON 数据源生成的可查表格。
:::

## 平台支持

| provider | iOS | Android | HarmonyOS |
|---|---|---|---|
| `amap`（高德） | <IconCheck /> 已验证 | <IconCheck /> 已验证 | <IconFlask /> 实验性 |
| `baidu`（百度） | <IconAlert /> 默认关闭¹ | <IconCheck /> 已验证 | <IconFlask /> 实验性 |
| `tencent`（腾讯） | <IconAlert /> 默认关闭¹ | <IconCheck /> 已验证 | <IconFlask /> 实验性 |
| `mapkit`（华为） | — | — | <IconFlask /> 实验性 |

<sub>¹ 百度 / 腾讯 iOS 适配器源码随包发布并固定了 pod 版本（`BaiduMapKit ~> 6.6.0` / `QMapKit ~> 5.6.0`），但**尚未真机验证**，默认关闭 iOS autolinking。如需尝试，在应用的 `react-native.config.js` 中为该包开启 `ios: {}` 并自行真机验证。</sub>

- **HarmonyOS Next**（基于 [RNOH](https://gitee.com/openharmony-sig/ohos_react_native)）各厂商均为实验性：核心流程已真机验证，API 与接入方式仍可能调整。
- 不支持 `provider="google"` 与 Web。

## 组件能力（已知缺口）

下表汇总已知的厂商能力缺口；未列出的组件在已验证平台上按标准行为工作。空白处待细化验证。

| 能力 | 高德 | 百度 | 腾讯 | 华为 |
|---|---|---|---|---|
| [Marker](../api/marker.md) / [Callout](../api/callout.md) | <IconCheck /> | <IconCheck /> | <IconCheck /> | <IconCheck /> |
| [Polyline](../api/polyline.md) / [Polygon](../api/polygon.md) / [Circle](../api/circle.md) | <IconCheck /> | <IconCheck />（Polygon 无孔洞²） | <IconCheck /> | <IconCheck /> |
| [Heatmap](../api/heatmap.md) | <IconCheck />（需 Jetifier） | <IconX /> 未接通 | <IconX /> 未接通 | <IconFlask /> |
| [瓦片图层](../api/url-tile.md)（Url/Local/WMS） | <IconCheck /> | <IconX /> 未接通 | <IconX /> 未接通 | <IconFlask /> |
| [Overlay](../api/overlay.md) 图片覆盖物 | <IconCheck /> | — | — | <IconFlask /> |
| [Geojson](../api/geojson.md)（纯 JS） | <IconCheck /> | <IconCheck /> | <IconCheck /> | <IconCheck /> |
| 标记坐标动画 `animateMarkerToCoordinate` | <IconCheck /> | <IconAlert /> 直接设置³ | <IconAlert /> 直接设置³ | <IconFlask /> |

<sub>² 百度 polygon API 不支持孔洞，`holes` 会被丢弃。</sub>
<sub>³ 百度/腾讯的标记坐标动画为直接设置位置，无内置补间。</sub>

图例：<IconCheck /> 支持 · <IconAlert /> 有限/降级 · <IconX /> 未接通 · <IconFlask /> 实验性（HarmonyOS） · — 不适用

## 数据来源

- 高德：iOS + Android 构建验证，参考适配器。
- 百度 / 腾讯：适配器按各自 SDK API 编写，Android 已验证；iOS 待真机验证。已知缺口见各厂商原生配置页（[百度](../native-setup/baidu.md#已知缺口) / [腾讯](../native-setup/tencent.md#已知缺口)）。
- HarmonyOS：核心流程真机验证通过，能力面随迭代补齐。

发现与文档不符的行为，欢迎在 [GitHub Issues](https://github.com/popsiclelmlm/react-native-cn-maps/issues) 反馈。
