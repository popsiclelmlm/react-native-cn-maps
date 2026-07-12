---
id: polygon
title: Polygon
sidebar_label: Polygon
description: Polygon 多边形组件的 props 与事件参考，含孔洞（holes）。
---

# Polygon

多边形覆盖物，支持 `holes` 孔洞。作为 `<MapView>` 的子节点渲染。也导出为 `MapPolygon`。

:::note 基础版
本页为 API 骨架，含完整 props 表；用法示例与厂商差异仍在补充中。
:::

```tsx
import MapView, { Polygon } from 'react-native-cn-maps';

<Polygon
  coordinates={outerRing}
  holes={[innerRing]}
  strokeColor="#1f6feb"
  fillColor="rgba(31,111,235,0.2)"
  strokeWidth={2}
/>;
```

## props

| Prop | 类型 | 说明 |
|---|---|---|
| `coordinates` | `LatLng[]` | **必填**。外环顶点。 |
| `holes` | `LatLng[][]` | 孔洞环（百度不支持，会被丢弃）。 |
| `strokeColor` | `ColorValue` | 描边颜色。 |
| `strokeWidth` | `number` | 线宽。 |
| `fillColor` | `ColorValue` | 填充色。 |
| `lineDashPattern` | `number[]` | 虚线段长模式。 |
| `lineDashPhase` | `number` | 虚线相位。 |
| `lineCap` | `'butt' \| 'round' \| 'square'` | 线端样式。 |
| `lineJoin` | `'miter' \| 'round' \| 'bevel'` | 拐角样式。 |
| `miterLimit` | `number` | 斜接限制。 |
| `geodesic` | `boolean` | 测地线绘制。 |
| `zIndex` | `number` | 层级。 |
| `tappable` | `boolean` | 是否可点击。 |

## 事件

| 事件 | `e.nativeEvent` | 说明 |
|---|---|---|
| `onPress` | `{ coordinate, position }` | 点击多边形（需 `tappable`）。 |
