---
id: geojson
title: Geojson
sidebar_label: Geojson
description: Geojson 组件的 props 参考——纯 JS 渲染 GeoJSON 点/线/面。
---

# Geojson

纯 JS 的 GeoJSON 渲染器——把一个 GeoJSON `FeatureCollection` 展开为 [`Marker`](./marker.md) / [`Polyline`](./polyline.md) / [`Polygon`](./polygon.md) 覆盖物（含孔洞）。因为在 JS 层展开，各厂商表现一致。作为 `<MapView>` 的子节点渲染。

:::note 基础版
本页为 API 骨架，含完整 props 表；用法示例仍在补充中。
:::

```tsx
import MapView, { Geojson } from 'react-native-cn-maps';

<Geojson
  geojson={featureCollection}
  strokeColor="#1f6feb"
  fillColor="rgba(31,111,235,0.2)"
  strokeWidth={2}
/>;
```

## props

| Prop | 类型 | 说明 |
|---|---|---|
| `geojson` | `object` | **必填**。GeoJSON `FeatureCollection`。 |
| `strokeColor` | `ColorValue` | 线/面描边颜色。 |
| `fillColor` | `ColorValue` | 面填充色。 |
| `strokeWidth` | `number` | 线宽。 |
| `lineDashPattern` | `number[]` | 虚线段长模式。 |
| `lineDashPhase` | `number` | 虚线相位。 |
| `markerComponent` | `ReactNode` | 点要素的自定义标记组件。 |
| `image` | `MarkerImageSource` | 点要素的图标。 |
| `pinColor` | `ColorValue` | 点要素的图钉颜色。 |
| `title` | `string` | 点要素气泡标题。 |
| `zIndex` | `number` | 层级。 |
| `tappable` | `boolean` | 是否可点击。 |
| `tracksViewChanges` | `boolean` | 自定义标记是否跟踪重绘。 |

## 事件

| 事件 | `e.nativeEvent` | 说明 |
|---|---|---|
| `onPress` | `{ coordinate, position }` | 点击要素（需 `tappable`）。 |

## 相关

- KML 通过 `<MapView kmlSrc="...">` 加载，内部同样解析为 GeoJSON 渲染，见 [MapView](./map-view.md#kml)。
