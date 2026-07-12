---
id: map-view
title: MapView
sidebar_label: MapView
description: MapView 组件的完整 props、事件与 ref 方法参考。
---

# MapView

地图容器组件，也是本库的默认导出。所有覆盖物（`Marker`、`Polyline` 等）作为它的 children 渲染。

```tsx
import MapView, { Marker } from 'react-native-cn-maps';

<MapView
  provider="amap"
  coordinateSystem="wgs84"
  style={{ flex: 1 }}
  initialRegion={{
    latitude: 31.2304,
    longitude: 121.4737,
    latitudeDelta: 0.05,
    longitudeDelta: 0.05,
  }}
>
  <Marker coordinate={{ latitude: 31.2304, longitude: 121.4737 }} />
</MapView>;
```

`MapView` 继承 React Native `View` 的所有 props（`style`、`onLayout` 等）。下面只列地图特有的。

## 核心 props

| Prop | 类型 | 默认 | 说明 |
|---|---|---|---|
| `provider` | `'amap' \| 'baidu' \| 'tencent' \| 'mapkit'` | `'amap'` | 地图厂商。挂载后固定，切换需重挂（`key={provider}`）。 |
| `coordinateSystem` | `'gcj02' \| 'wgs84' \| 'bd09'` | `'gcj02'` | 你传入坐标的坐标系，库自动转换。见[坐标系专题](../guides/coordinate-systems.md)。 |
| `initialRegion` | `Region` | — | 首次挂载的视野（非受控）。 |
| `region` | `Region \| AnimatedRegion` | — | 受控视野；传 `AnimatedRegion` 可驱动动画。 |
| `initialCamera` | `Camera` | — | 首次挂载的相机（非受控）。 |
| `camera` | `Camera` | — | 受控相机。**同时给 `region` 和 `camera` 时 `camera` 优先**。 |

`Region` = `{ latitude, longitude, latitudeDelta, longitudeDelta }`；`Camera` = `{ center: LatLng, zoom, heading, pitch, altitude? }`。

## 外观 props

| Prop | 类型 | 说明 |
|---|---|---|
| `mapType` | `'standard' \| 'satellite' \| 'hybrid' \| 'terrain' \| 'none' \| 'mutedStandard' \| 'satelliteFlyover' \| 'hybridFlyover'` | 底图类型。iOS-only 类型在国内厂商上降级为最接近的样式。 |
| `customMapStyle` | `MapStyleElement[]` | 自定义样式规则。 |
| `userInterfaceStyle` | `'light' \| 'dark'` | 明暗风格。 |
| `tintColor` | `ColorValue` | 主题色。 |
| `mapPadding` | `EdgePadding` | 地图内边距 `{ top, right, bottom, left }`。 |
| `minZoomLevel` / `maxZoomLevel` | `number` | 缩放级别范围。 |

## 手势开关

| Prop | 类型 | 说明 |
|---|---|---|
| `zoomEnabled` | `boolean` | 缩放手势。 |
| `zoomTapEnabled` | `boolean` | 双击缩放。 |
| `zoomControlEnabled` | `boolean` | 缩放控件（Android）。 |
| `scrollEnabled` | `boolean` | 拖动。 |
| `scrollDuringRotateOrZoomEnabled` | `boolean` | 旋转/缩放时允许拖动。 |
| `rotateEnabled` | `boolean` | 旋转手势。 |
| `pitchEnabled` | `boolean` | 俯仰手势。 |

## 显示开关

| Prop | 类型 | 说明 |
|---|---|---|
| `showsUserLocation` | `boolean` | 显示定位蓝点。 |
| `followsUserLocation` | `boolean` | 跟随用户位置。 |
| `userLocationPriority` | `'balanced' \| 'high' \| 'low' \| 'passive'` | 定位精度优先级。 |
| `showsMyLocationButton` | `boolean` | 定位按钮（Android）。 |
| `showsCompass` | `boolean` | 指南针。 |
| `showsScale` | `boolean` | 比例尺。 |
| `showsTraffic` | `boolean` | 路况。 |
| `showsBuildings` | `boolean` | 3D 建筑。 |
| `showsIndoors` / `showsIndoorLevelPicker` | `boolean` | 室内图与楼层选择器。 |
| `showsPointsOfInterest` | `boolean` | POI 标注。**尽力而为**：高德无 POI-only 开关，实际会切换**所有**地图文字标注。 |

> 更多 Android-only（`toolbarEnabled`、`liteMode`、`cacheEnabled`、`paddingAdjustmentBehavior`）与加载态（`loadingEnabled`、`loadingIndicatorColor`、`loadingBackgroundColor`）等 props，见 `packages/core/src/types.ts` 的 `MapViewProps`。

## KML

| Prop | 类型 | 说明 |
|---|---|---|
| `kmlSrc` | `string` | KML 源：http(s) URL，或以 `<` 开头的内联 KML 字符串。国内 SDK 无原生 KML 加载器，本库在 JS 层解析后作为 `<Geojson>`（WGS-84）渲染。 |

## 事件

所有事件回调形如 `(e) => void`，数据在 `e.nativeEvent`，坐标已转换回你声明的 `coordinateSystem`。

| 事件 | `e.nativeEvent` | 说明 |
|---|---|---|
| `onRegionChange` | `{ region, isGesture? }` | 视野持续变化。 |
| `onRegionChangeComplete` | `{ region, isGesture? }` | 视野变化结束。 |
| `onMapReady` | — | 地图就绪。 |
| `onMapLoaded` | — | 地图瓦片加载完成。 |
| `onPress` | `{ coordinate, position }` | 点击地图（点标注的点击不触发，对齐 iOS 语义）。 |
| `onLongPress` | `{ coordinate, position }` | 长按。 |
| `onDoublePress` | `{ coordinate, position }` | 双击。 |
| `onPanDrag` | `{ coordinate, position }` | 拖动。 |
| `onPoiClick` | `{ coordinate, placeId?, name? }` | 点击 POI。 |
| `onUserLocationChange` | `{ coordinate? }` | 用户位置更新（含 `altitude` / `accuracy` / `speed` / `heading` 等）。 |
| `onIndoorBuildingFocused` / `onIndoorLevelActivated` | 见类型 | 室内图事件。 |
| `onKmlReady` | `{ markers }` | KML 解析完成。 |

`MapView` 还转发 Marker 的事件（RNM parity）：`onMarkerPress`、`onMarkerSelect`、`onMarkerDeselect`、`onMarkerDragStart`、`onMarkerDrag`、`onMarkerDragEnd`、`onCalloutPress`。优先在 [`<Marker>`](./marker.md) 自身上监听。

## 方法（ref）

通过 `ref` 拿到 `MapViewHandle` 命令式调用：

```tsx
import { useRef } from 'react';
import MapView, { type MapViewHandle } from 'react-native-cn-maps';

const mapRef = useRef<MapViewHandle>(null);
// mapRef.current?.animateToRegion(region, 800);
```

### 视野 / 相机

| 方法 | 签名 | 说明 |
|---|---|---|
| `animateToRegion` | `(region: Region, duration = 500) => void` | 平滑移动到区域。 |
| `animateCamera` | `(camera: Partial<Camera>, opts?: { duration?: number }) => void` | 平滑移动相机。 |
| `setCamera` | `(camera: Partial<Camera>) => void` | 立即设置相机。 |
| `getCamera` | `() => Promise<Camera>` | 读取当前相机。 |

### 边界 / 适配

| 方法 | 签名 | 说明 |
|---|---|---|
| `fitToCoordinates` | `(coordinates: LatLng[], options?: { edgePadding?, animated? }) => void` | 适配到一组坐标。 |
| `fitToElements` | `(options?: { animated? }) => void` | 适配到所有覆盖物。 |
| `fitToSuppliedMarkers` | `(markerIDs: string[], options?) => void` | 适配到指定 marker。 |
| `setMapBoundaries` | `(northEast: LatLng, southWest: LatLng) => void` | 限制可视范围。 |
| `getMapBoundaries` | `() => Promise<BoundingBox>` | 读取当前可视范围。 |

### 坐标 ↔ 屏幕点

| 方法 | 签名 | 说明 |
|---|---|---|
| `pointForCoordinate` | `(coordinate: LatLng) => Promise<Point>` | 经纬度 → 屏幕像素点。 |
| `coordinateForPoint` | `(point: Point) => Promise<LatLng>` | 屏幕像素点 → 经纬度。 |

### 其他

| 方法 | 签名 | 说明 |
|---|---|---|
| `addressForCoordinate` | `(coordinate: LatLng) => Promise<Address>` | 逆地理编码。 |
| `takeSnapshot` | `(options?: SnapshotOptions) => Promise<string>` | 截图，返回 `file://` uri 或 base64。 |
| `getMarkersFrames` | `(onlyVisible = false) => Promise<Record<string, { point, frame }>>` | 各 marker 的屏幕位置与尺寸。 |

:::note Promise 方法的超时
`getCamera`、`getMapBoundaries` 等查询命令若原生侧 10 秒内无响应会 reject，不会永久挂起；MapView 卸载时未决的查询也会被 reject。
:::

## AnimatedRegion

`region` 可传 `AnimatedRegion` 实例来驱动视野动画（RNM parity）。`AnimatedRegion` 包装了四个 `Animated.Value`，MapView 会把每帧的值合并成一次 `animateToRegion`。

```tsx
import { AnimatedRegion, Animated as AnimatedMapView } from 'react-native-cn-maps';
```
