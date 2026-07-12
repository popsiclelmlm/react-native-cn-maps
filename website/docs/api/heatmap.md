---
id: heatmap
title: Heatmap
sidebar_label: Heatmap
description: Heatmap 热力图组件的 props 与类型参考。
---

# Heatmap

权重点热力图。作为 `<MapView>` 的子节点渲染。也导出为 `MapHeatmap`。

:::note 基础版
本页为 API 骨架，含完整 props 表；用法示例与厂商差异仍在补充中。热力图目前仅高德接通（需开启 Jetifier，见[高德配置](../native-setup/amap.md#heatmap-的-jetifier)）；百度/腾讯 TODO，见[支持矩阵](../guides/provider-matrix.md)。
:::

```tsx
import MapView, { Heatmap } from 'react-native-cn-maps';

<Heatmap
  points={[
    { latitude: 31.2304, longitude: 121.4737, weight: 1 },
    { latitude: 31.2404, longitude: 121.4837, weight: 0.5 },
  ]}
  radius={40}
  opacity={0.7}
/>;
```

## props

| Prop | 类型 | 说明 |
|---|---|---|
| `points` | `HeatmapPoint[]` | **必填**。权重点数组。 |
| `radius` | `number` | 每个点的影响半径。 |
| `opacity` | `number` | 不透明度。 |
| `gradient` | `HeatmapGradient` | 颜色渐变配置。 |

## 类型

```ts
type HeatmapPoint = {
  latitude: number;
  longitude: number;
  weight?: number; // 权重，默认 1
};

type HeatmapGradient = {
  colors: ColorValue[];      // 渐变颜色
  startPoints: number[];     // 各颜色的起始位置（0–1）
  colorMapSize: number;      // 颜色映射表尺寸
};
```
