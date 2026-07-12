---
id: marker
title: Marker
sidebar_label: Marker
description: Marker 标记组件的 props、事件与 ref 方法参考。
---

# Marker

地图标记。作为 `<MapView>` 的子节点渲染。也导出为 `MapMarker`，动画版为 `MarkerAnimated`（或 `Marker.Animated`）。

```tsx
import MapView, { Marker } from 'react-native-cn-maps';

<MapView provider="amap" coordinateSystem="wgs84" style={{ flex: 1 }} initialRegion={/* ... */}>
  <Marker
    coordinate={{ latitude: 31.2304, longitude: 121.4737 }}
    title="上海"
    description="外滩附近"
    pinColor="#1f6feb"
    draggable
    onDragEnd={(e) => console.log('拖到', e.nativeEvent.coordinate)}
  />
</MapView>;
```

## props

| Prop | 类型 | 说明 |
|---|---|---|
| `coordinate` | `LatLng` | **必填**。标记位置。 |
| `identifier` | `string` | 标识符，用于 `fitToSuppliedMarkers` 等。 |
| `title` | `string` | 默认气泡标题。 |
| `description` | `string` | 默认气泡描述。 |

### 外观

| Prop | 类型 | 说明 |
|---|---|---|
| `pinColor` | `ColorValue` | 默认图钉颜色（支持 `rgba` 与命名色）。 |
| `image` | `MarkerImageSource` | 自定义图标（`require` / uri / uri 数组）。 |
| `icon` | `MarkerImageSource` | 同 `image` 的别名语义。 |
| `anchor` | `Point` | 锚点（0–1），决定图标哪个点对准坐标。 |
| `centerOffset` | `Point` | 中心偏移。 |
| `calloutAnchor` | `Point` | 气泡锚点。 |
| `opacity` | `number` | 不透明度。 |
| `rotation` | `number` | 旋转角度。 |
| `flat` | `boolean` | 是否贴地（随地图旋转/俯仰）。 |
| `zIndex` | `number` | 层级。 |

> 也可以把任意 React 子视图作为 `<Marker>` 的 children，库会栅格化为标记图标（自定义标记）。

### 行为

| Prop | 类型 | 说明 |
|---|---|---|
| `draggable` | `boolean` | 可拖拽。 |
| `tappable` | `boolean` | 可点击。 |
| `tracksViewChanges` | `boolean` | 是否跟踪子视图变化重绘（自定义标记性能相关）。 |
| `tracksInfoWindowChanges` | `boolean` | 是否跟踪气泡内容变化重绘。 |
| `stopPropagation` | `boolean` | 阻止事件冒泡到地图。 |
| `isPreselected` | `boolean` | 初始选中。 |

## 事件

| 事件 | `e.nativeEvent` | 说明 |
|---|---|---|
| `onPress` | `{ coordinate, identifier, position? }` | 点击标记。 |
| `onSelect` | `{ coordinate, identifier }` | 选中。 |
| `onDeselect` | `{ coordinate, identifier }` | 取消选中。 |
| `onCalloutPress` | `{ identifier?, point?, frame? }` | 点击气泡。 |
| `onDragStart` | `{ coordinate, identifier? }` | 开始拖拽。 |
| `onDrag` | `{ coordinate, identifier? }` | 拖拽中。 |
| `onDragEnd` | `{ coordinate, identifier? }` | 拖拽结束。 |

## 方法（ref）

通过 `ref` 拿到 `MapMarkerHandle`：

| 方法 | 签名 | 说明 |
|---|---|---|
| `showCallout` | `() => void` | 显示气泡。 |
| `hideCallout` | `() => void` | 隐藏气泡。 |
| `redrawCallout` | `() => void` | 重绘气泡。 |
| `redraw` | `() => void` | 重绘标记。 |
| `animateMarkerToCoordinate` | `(coordinate: LatLng, duration?: number) => void` | 平滑移动标记到新坐标（部分厂商为直接设置，见[支持矩阵](../guides/provider-matrix.md)）。 |

```tsx
import { useRef } from 'react';
import { Marker, type MapMarkerHandle } from 'react-native-cn-maps';

const markerRef = useRef<MapMarkerHandle>(null);
// markerRef.current?.showCallout();
```

## 相关

- 自定义气泡见 [Callout](./callout.md) / [CalloutSubview](./callout-subview.md)。
- 标记的坐标遵循 `<MapView coordinateSystem>`，见[坐标系专题](../guides/coordinate-systems.md)。
