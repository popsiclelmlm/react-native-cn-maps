---
id: polyline
title: Polyline
sidebar_label: Polyline
description: Polyline 折线组件的 props 与事件参考，含渐变描边与虚线。
---

# Polyline

折线覆盖物。作为 `<MapView>` 的子节点渲染。也导出为 `MapPolyline`。

```tsx
import MapView, { Polyline } from 'react-native-cn-maps';

<MapView provider="amap" coordinateSystem="wgs84" style={{ flex: 1 }} initialRegion={/* ... */}>
  <Polyline
    coordinates={[
      { latitude: 31.2304, longitude: 121.4737 },
      { latitude: 31.2404, longitude: 121.4837 },
      { latitude: 31.2504, longitude: 121.4937 },
    ]}
    strokeColor="#1f6feb"
    strokeWidth={4}
    lineCap="round"
  />
</MapView>;
```

## props

| Prop | 类型 | 说明 |
|---|---|---|
| `coordinates` | `LatLng[]` | **必填**。折线顶点。 |
| `strokeColor` | `ColorValue` | 描边颜色。 |
| `strokeColors` | `ColorValue[]` | 渐变描边颜色数组（按段插值）。 |
| `strokeWidth` | `number` | 线宽（逻辑点）。 |
| `lineCap` | `'butt' \| 'round' \| 'square'` | 线端样式。 |
| `lineJoin` | `'miter' \| 'round' \| 'bevel'` | 拐角样式。 |
| `miterLimit` | `number` | miter 拐角的斜接限制。 |
| `lineDashPattern` | `number[]` | 虚线段长模式。 |
| `lineDashPhase` | `number` | 虚线相位偏移。 |
| `geodesic` | `boolean` | 是否按大地测地线绘制。 |
| `zIndex` | `number` | 层级。 |
| `tappable` | `boolean` | 是否可点击。 |

## 事件

| 事件 | `e.nativeEvent` | 说明 |
|---|---|---|
| `onPress` | `{ coordinate, position }` | 点击折线（需 `tappable`）。 |

## 渐变折线

传 `strokeColors` 会在相邻顶点间对颜色插值：

```tsx
<Polyline
  coordinates={coords}
  strokeColors={['#00c6ff', '#0072ff', '#ff0080']}
  strokeWidth={6}
/>
```

## 相关

- 面覆盖物见 [Polygon](./polygon.md)（支持孔洞）、[Circle](./circle.md)。
- 坐标遵循 `<MapView coordinateSystem>`，见[坐标系专题](../guides/coordinate-systems.md)。
