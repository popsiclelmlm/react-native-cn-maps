# 从 react-native-maps 迁移

> 目标:把 `import ... from 'react-native-maps'` 改成 `'react-native-cn-maps'` 即可迁移到国内地图 SDK(当前 provider:高德 / AMap)。本表记录每个 API 的支持状态。
>
> 图例:✅ 已支持 · ⚠️ 有差异 / best-effort · ❌ 未实现(占位,运行时 `__DEV__` 警告)

## 重要差异:坐标系

react-native-maps 默认 WGS-84;国内 SDK 用 GCJ-02。用 `<MapView coordinateSystem>` 声明你传入坐标的坐标系,库会在 **JS 层**统一转换:

```tsx
<MapView coordinateSystem="wgs84" /> // 你的坐标是 GPS/WGS-84,自动转 gcj02
<MapView coordinateSystem="gcj02" /> // 默认;不转换
```

`bd09`(百度)在坐标转换层已预留,但百度 provider 本体未接入。

## 组件

| 组件 | 状态 | 说明 |
|------|------|------|
| `MapView` | ✅ | provider 当前仅 `amap` |
| `Marker` | ✅ | 真 Fabric 子组件,支持自定义 React 内容 |
| `Callout` | ✅ | iOS 栅格化气泡 / Android InfoWindow |
| `CalloutSubview` | ⚠️ | 渲染内容;子项独立点击未路由(用 `Callout`/`Marker` 整体点击) |
| `Polyline` | ✅ | `strokeColors` 渐变未实现 |
| `Polygon` | ✅ | `holes` 仅 iOS;Android 暂不支持 |
| `Circle` | ✅ | |
| `Overlay` | ❌ | 占位 |
| `Geojson` | ❌ | 占位 |
| `Heatmap` | ❌ | 占位 |
| `UrlTile` / `WMSTile` / `LocalTile` | ❌ | 占位 |
| `AnimatedRegion` | ✅ | 4×`Animated.Value`;驱动地图时退化为 `animateToRegion` |
| `PROVIDER_GOOGLE` / `PROVIDER_DEFAULT` | ⚠️ | 存在,均映射到当前 provider |

## MapView props

| prop | 状态 | 说明 |
|------|------|------|
| `initialRegion` / `region` | ✅ | `region` 也接受 `AnimatedRegion` |
| `initialCamera` / `camera` | ✅ | `camera` 优先于 `region` |
| `mapType` | ⚠️ | `satellite`/`hybrid`→卫星,其余→标准 |
| `customMapStyle` | ⚠️ | Google 风格 JSON 与 AMap 不兼容,忽略 + 警告 |
| `userInterfaceStyle` | ⚠️ | `dark`→夜间地图 |
| `minZoomLevel` / `maxZoomLevel` | ✅ | |
| 手势开关(`zoomEnabled`/`scrollEnabled`/`rotateEnabled`/`pitchEnabled`…) | ✅ | 部分细分开关 best-effort |
| 显示开关(`showsTraffic`/`showsBuildings`/`showsCompass`/`showsScale`/`showsIndoors`/`showsUserLocation`/`showsPointsOfInterest`…) | ✅ | |
| `mapPadding` / `tintColor` / `kmlSrc` / `loading*` | ❌/⚠️ | 无对应 AMap 能力,忽略 |
| `toolbarEnabled` / `liteMode` / `cacheEnabled`(Android) | ⚠️ | Google 概念,忽略 |

## MapView 事件

| 事件 | 状态 |
|------|------|
| `onMapReady` / `onMapLoaded` | ✅ |
| `onRegionChange` / `onRegionChangeComplete` | ✅(带 `isGesture`) |
| `onPress` / `onLongPress` / `onDoublePress` / `onPanDrag` | ✅ |
| `onPoiClick` | ✅ |
| `onUserLocationChange` | ✅ |
| `onIndoorBuildingFocused` / `onIndoorLevelActivated` / `onKmlReady` | ❌ |

## MapView ref 方法

| 方法 | 状态 |
|------|------|
| `animateToRegion` | ✅ |
| `animateCamera` / `setCamera` | ✅ |
| `getCamera` | ✅(Promise) |
| `fitToCoordinates` / `fitToElements` / `fitToSuppliedMarkers` | ✅ |
| `getMapBoundaries` | ✅(Promise) |
| `pointForCoordinate` / `coordinateForPoint` | ✅(Promise) |
| `setMapBoundaries` / `getMarkersFrames` / `setIndoorActiveLevelIndex` / `addressForCoordinate` | ❌ |

## Marker

| 能力 | 状态 | 说明 |
|------|------|------|
| `coordinate` / `title` / `description` / `pinColor` | ✅ | |
| `image` / `icon` | ✅ | `resolveAssetSource` → uri,native 异步加载 |
| `anchor` | ⚠️ | Android 生效;iOS 用 `centerOffset` |
| `centerOffset` / `calloutAnchor` | ⚠️ | iOS 生效;Android 无对应 |
| `opacity` / `rotation` / `flat` / `zIndex` | ✅ | `flat` iOS 无对应 |
| `draggable` | ✅ | |
| `tracksViewChanges` / `tracksInfoWindowChanges` | ✅/⚠️ | |
| 自定义子内容 `<Marker>{…}</Marker>` | ✅ | 离屏栅格化为图标 |
| 事件 `onPress` / `onSelect` / `onDeselect` / `onDragStart` / `onDrag` / `onDragEnd` / `onCalloutPress` | ✅ | `onDeselect` Android 不触发 |
| ref:`showCallout` / `hideCallout` / `redrawCallout` / `redraw` / `animateMarkerToCoordinate` | ✅ | |

## Provider 路线

| provider | 状态 |
|----------|------|
| 高德 AMap | ✅ |
| 百度 Baidu (`coordinateSystem="bd09"`) | ⏸ 规划中 |
| 腾讯 Tencent | ⏸ 规划中 |

## 平台

| 平台 | 状态 |
|------|------|
| iOS (MAMapKit) | ✅ |
| Android (AMap) | ✅ |
| Web (react-native-web) | ❌ 不支持(本库定位 RN 原生) |
