# 从 react-native-maps 迁移到 react-native-cn-maps（Android）

`react-native-cn-maps` 在 **API 形状上对标 [react-native-maps](https://github.com/react-native-maps/react-native-maps)**：组件名、props、imperative 方法、事件、类型导出尽量一致，目标是**绝大多数项目只改 import 即可迁移**。

本指南聚焦 **Android**（高德 / 百度 / 腾讯三家国内地图）。所有结论均在 Android 模拟器实测，详见 [ANDROID_MULTI_PROVIDER_VERIFICATION.md](./ANDROID_MULTI_PROVIDER_VERIFICATION.md)。

---

## 1. 三步迁移

### ① 改 import

```diff
- import MapView, { Marker, Polyline, PROVIDER_GOOGLE } from 'react-native-maps';
+ import MapView, { Marker, Polyline, PROVIDER_GOOGLE } from 'react-native-cn-maps';
```

默认导出（`MapView`）、所有命名导出（`Marker`/`MapMarker`/`Callout`/`Polygon`/`Polyline`/`Circle`/`Overlay`/`Heatmap`/`Geojson`/`UrlTile`/`WMSTile`/`LocalTile`/`CalloutSubview`/`AnimatedRegion`/`Animated`/`MarkerAnimated`/`OverlayAnimated`/`PROVIDER_GOOGLE`/`PROVIDER_DEFAULT`/`MAP_TYPES`）以及全部 TS 类型（`Region`/`LatLng`/`Camera`/`MapType`/`Address`/…）名称一致。

### ② 装 provider 包 + 配 Key

核心包 `react-native-cn-maps` 不含任何厂商 SDK；按需安装 provider 包：

```bash
yarn add react-native-cn-maps react-native-cn-maps-amap   # 高德
# 可选：react-native-cn-maps-baidu / react-native-cn-maps-tencent
```

Key 写进 `AndroidManifest.xml`（`<application>` 内）：

```xml
<meta-data android:name="com.amap.api.v2.apikey"  android:value="${AMAP_ANDROID_API_KEY}" />
<meta-data android:name="com.baidu.lbsapi.API_KEY" android:value="${BAIDU_ANDROID_API_KEY}" />
<meta-data android:name="TencentMapSDK"            android:value="${TENCENT_ANDROID_API_KEY}" />
```

> 腾讯额外需要 `ACCESS_NETWORK_STATE`、`ACCESS_WIFI_STATE` 权限，且其 SDK 仅在腾讯 maven 镜像 `https://mirrors.tencent.com/repository/maven/tencent_public/`。

### ③ 隐私合规 + provider

国内地图 SDK 有法律强制的隐私合规开关，必须在挂载 `<MapView>` **之前**调用一次：

```ts
import { setPrivacyConsent } from 'react-native-cn-maps';
setPrivacyConsent({ agreed: true, contains: true, shown: true });
```

把 `provider` 从 `'google'`/`undefined` 改为国内 provider：

```diff
- <MapView provider={PROVIDER_GOOGLE} ... />
+ <MapView provider="amap" ... />   // 'amap' | 'baidu' | 'tencent'
```

> 兼容：`PROVIDER_GOOGLE` 与 `PROVIDER_DEFAULT` 都映射到默认 provider（`amap`），所以即便忘了改 `provider={PROVIDER_GOOGLE}` 也不会崩，只是用高德渲染。

---

## 2. ⚠️ 迁移必读：坐标系

这是与 react-native-maps **唯一会导致坐标偏移**的实质差异。

| 库 | 坐标系 |
|---|---|
| react-native-maps（Google/Apple） | **WGS-84**（GPS 原始） |
| 高德 / 腾讯 | **GCJ-02**（国测局加密） |
| 百度 | **BD-09** |

`react-native-cn-maps` 默认 `coordinateSystem="gcj02"`。**如果你的数据是 WGS-84（来自 GPS、后端、react-native-maps 老代码），必须显式声明**，否则会有几十~上百米偏移：

```tsx
<MapView coordinateSystem="wgs84" provider="amap" ... />
```

JS 层会自动把你声明坐标系的输入/输出在 provider 原生坐标系之间换算（marker、region、camera、事件回调全部覆盖）。你的代码始终用自己声明的坐标系，无需手动转换。

---

## 3. 对标矩阵（Android）

图例：✅ 支持 · 🟡 接受但受 provider 限制（不报错、优雅降级）· ⛔ iOS-only（Android 接受 prop 但无效）

### 组件

| 组件 | 状态 | 备注 |
|---|:--:|---|
| `MapView` | ✅ | 三家均渲染 + 鉴权通过（实测） |
| `Marker` | ✅ | pinColor / image / icon / 自定义 React view / draggable / 标签 |
| `Callout` / `CalloutSubview` | ✅ | 自定义气泡（光栅化为 InfoWindow）；单个 subview 独立点击未路由，用 `Callout.onPress` |
| `Polyline` | ✅ | 含 strokeColors 渐变、dash、geodesic |
| `Polygon` | ✅ | 含 holes 挖洞 |
| `Circle` | ✅ | |
| `Heatmap` | ✅ | 加权点 + gradient |
| `Geojson` | ✅ | point + line + polygon（纯 JS 渲染） |
| `Overlay`（GroundOverlay） | ✅ | image + bounds + bearing + opacity；`tappable` 无原生点击 |
| `UrlTile` | ✅ | `{x}{y}{z}` 栅格；OSM 公共服务器会拒默认 UA，需自备瓦片源 |
| `WMSTile` | ✅ | EPSG:3857 bbox |
| `LocalTile` | ✅ | 文件/assets 瓦片 |

### MapView imperative 方法（`ref`）

| 方法 | 状态 |
|---|:--:|
| `animateToRegion` / `animateCamera` / `setCamera` / `getCamera` | ✅ |
| `fitToCoordinates` / `fitToElements` / `fitToSuppliedMarkers` | ✅ |
| `getMapBoundaries` / `setMapBoundaries` | ✅ |
| `pointForCoordinate` / `coordinateForPoint` | ✅ |
| `getMarkersFrames` | ✅ |
| `takeSnapshot`（file / base64） | ✅ |
| `addressForCoordinate`（逆地理编码） | ✅ 高德实测可用；百度/腾讯返回空 |
| `setIndoorActiveLevelIndex` | 🟡 |

### Marker 方法

`showCallout` / `hideCallout` / `redraw` / `redrawCallout` / `animateMarkerToCoordinate` — 均 ✅。

### 事件

| 事件 | 状态 |
|---|:--:|
| `onMapReady` / `onMapLoaded` | ✅ |
| `onRegionChange` / `onRegionChangeComplete`（含 `isGesture`） | ✅（腾讯 isGesture 恒 false） |
| `onPress` / `onLongPress` / `onDoublePress` | ✅ |
| `onPanDrag`（逐帧） | ✅ 三家均支持（高德/百度=地图触摸观察；腾讯=dispatchTouchEvent） |
| `onPoiClick` | ✅ |
| `onUserLocationChange` | ✅ |
| `onMarkerPress` / `onMarkerSelect` / `onMarkerDeselect` | ✅ |
| `onMarkerDragStart` / `onMarkerDrag` / `onMarkerDragEnd` | ✅ |
| `onCalloutPress` | ✅ |
| `kmlSrc` / `onKmlReady` | ✅ 内置 JS KML 解析 → 用 `Geojson` 渲染（Point/Line/Polygon），并回调 `onKmlReady` |

---

## 4. Android 已知差异 / provider 限制（诚实清单）

这些 prop **都能传、不会崩**，只是底层国内 SDK 无对应能力 → 优雅忽略：

| Prop / 能力 | 说明 |
|---|---|
| `customMapStyle` | RNM 用 Google 的 JSON 样式；高德用**二进制样式文件**，两者不兼容，故 JSON 不生效。需自定义样式请用高德样式文件方案。 |
| `addressForCoordinate` | 高德 Android（GeocodeSearch）+ iOS（AMapSearch）均已实现；百度/腾讯返回空地址，不崩溃。 |
| `tintColor` / `mapPadding` | 高德 Android 无对应 API。 |
| `mapType: 'satelliteFlyover' / 'hybridFlyover'` | iOS-only 飞行视图；Android 降级为最接近底图。 |
| `loadingEnabled` / `loadingIndicatorColor` / `loadingBackgroundColor` | 高德自带加载 UI。 |
| `toolbarEnabled` / `liteMode` / `cacheEnabled` | Google Maps 专有概念，无高德等价。 |
| `zoomTapEnabled` / `scrollDuringRotateOrZoomEnabled` | 高德无独立开关，并入手势。 |
| Marker 的 `centerOffset` / `calloutOffset` / `displayPriority` / `titleVisibility` / `subtitleVisibility` / `useLegacyPinView` / `tracksInfoWindowChanges` | Apple Maps 专有，Android 接受但无效。 |

> 设计原则：**对标 react-native-maps 的 API 形状以保证「只改 import」**；底层 provider 不具备的能力**降级为 no-op 而非报错**，并在此如实记录。

---

## 5. 一个最小可运行例子

```tsx
import React from 'react';
import MapView, { Marker, Polyline, setPrivacyConsent } from 'react-native-cn-maps';

setPrivacyConsent({ agreed: true, contains: true, shown: true });

export default function App() {
  return (
    <MapView
      style={{ flex: 1 }}
      provider="amap"
      coordinateSystem="wgs84"          // 若数据是 GPS/WGS-84
      initialRegion={{
        latitude: 31.2304, longitude: 121.4737,
        latitudeDelta: 0.1, longitudeDelta: 0.1,
      }}
      onMapReady={() => console.log('ready')}
    >
      <Marker coordinate={{ latitude: 31.2397, longitude: 121.4998 }} title="外滩" />
      <Polyline
        coordinates={[
          { latitude: 31.2397, longitude: 121.4998 },
          { latitude: 31.2304, longitude: 121.4737 },
        ]}
        strokeColor="#ff0000"
        strokeWidth={4}
      />
    </MapView>
  );
}
```

与 react-native-maps 的写法**完全一致**，除了 import、`provider`、`coordinateSystem` 与隐私合规调用。
