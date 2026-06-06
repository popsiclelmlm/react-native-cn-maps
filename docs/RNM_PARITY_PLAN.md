# react-native-maps 对照

> 功能与 [`react-native-maps`](https://github.com/react-native-maps/react-native-maps) 的对照表,便于评估"换 import 即可迁移"的覆盖度。
>
> 范围:中国 provider(首发高德 AMap),React Native 新架构(Fabric)。Apple 专属能力(`legalLabelInsets` / `appleLogoInsets` 等)不在对标范围;`provider="google"` 不在范围。
>
> 配套阅读:从 `react-native-maps` 迁移过来的 API 映射见 [MIGRATION_FROM_RN_MAPS.md](MIGRATION_FROM_RN_MAPS.md)。

## 图例

✅ 已支持 · ⚠️ best-effort(SDK 差异/有限支持)· ⏸ 暂缓 · ❌ 不支持

> 双端(Android + iOS)真机/模拟器逐项验证全通过(2026-06-06)。

---

## 组件

| 组件 | 状态 | 说明 |
|------|------|------|
| `MapView` | ✅ | provider="amap";`initialRegion`/`region`/`initialCamera`/`camera` 受控 + 命令式 |
| `Marker` | ✅ | 默认 pin / `pinColor` / `image` / 自定义 React 子树(栅格化)/ 可拖拽 |
| `Callout` | ✅ | 自定义气泡(信息窗体),`onPress` 双端可用 |
| `Polyline` | ✅ | `strokeColors` 渐变、`lineCap` / `lineJoin` / `miterLimit`、`tappable` `onPress`(Android 双端;iOS) |
| `Polygon` | ✅ | `holes` 双端一致(Android `hollowShapes` / iOS `hollowShapes`) |
| `Circle` | ✅ | center / radius / stroke / fill |
| `Overlay` | ✅ | 图片按地理 `bounds` 贴图,支持 `bearing` 旋转、`opacity` |
| `UrlTile` | ✅ | `{x}/{y}/{z}` URL 模板,`minimumZ` / `maximumZ` / `tileSize` / `flipY` / 离线缓存目录 |
| `LocalTile` | ✅ | 本地文件系统 / assets 瓦片 |
| `WMSTile` | ✅ | WMS GetMap(EPSG:3857 bbox 替换),复用 UrlTile 通路 |
| `Heatmap` | ✅ | 加权点集 + radius + gradient;**Android host 需开 `android.enableJetifier=true`**(AMap 热力图依赖旧 Support 库) |
| `Geojson` | ✅ | 纯 JS,解析 GeoJSON 渲染对应 Marker/Polyline/Polygon;支持 Point/MultiPoint/LineString/MultiLineString/Polygon(含内孔)/MultiPolygon/GeometryCollection/Feature/FeatureCollection |
| Indoor maps | ⏸ | AMap `showIndoorMap` 已接,楼层 API 暂缓 |
| KML | ❌ | AMap 无原生 KML loader,暂不支持 |

## MapView props / events

| API | 状态 | 说明 |
|------|------|------|
| `provider` | ✅ | 目前仅 `"amap"` |
| `coordinateSystem` | ✅ | `gcj02` / `wgs84` / `bd09`,JS 层做坐标转换,native 恒收发 GCJ-02 |
| `initialRegion` / `region` | ✅ | 受控 region |
| `initialCamera` / `camera` | ✅ | 受控 camera(center/heading/pitch/zoom)|
| `mapType` | ⚠️ | `standard` / `satellite`;`hybrid` 映射到 satellite;`terrain` / `none` 不支持(AMap iOS/Android 无对应) |
| `userInterfaceStyle: 'dark'` | ✅ | Android 映射到 `MAP_TYPE_NIGHT` |
| `customMapStyle` | ✅ | 透传 JSON |
| `showsUserLocation` / `followsUserLocation` | ✅ | |
| `showsCompass` / `showsScale` / `showsTraffic` / `showsBuildings` / `showsIndoors` / `showsIndoorLevelPicker` | ✅ | `showsBuildings` 仅在倾斜 3D + 高缩放下可见(AMap 行为)|
| `showsPointsOfInterest` | ⚠️ | 切的是所有标注(POI + 街道 + 区名);AMap 无 POI-only 开关 |
| `showsMyLocationButton` | ✅ | Android;iOS best-effort |
| `zoomEnabled` / `scrollEnabled` / `rotateEnabled` / `pitchEnabled` | ✅ | |
| `minZoomLevel` / `maxZoomLevel` | ✅ | |
| `mapPadding` | ⏸ | Android 暂未接 |
| `loading*` / `tintColor` | ❌ | 与 MAMapKit 无对应 |
| `onMapReady` / `onMapLoaded` | ✅ | |
| `onPress` / `onLongPress` / `onDoublePress` / `onPanDrag` | ✅ | 含 `{ coordinate, position }` |
| `onRegionChange` / `onRegionChangeComplete` | ✅ | 含 `isGesture` |
| `onPoiClick` | ✅ | |
| `onUserLocationChange` | ✅ | |
| 子组件挂载(`<Marker>` 等) | ✅ | Fabric child host components,从 MapView 拦截路由 |

## MapView 命令(ref API)

| 命令 | 状态 |
|------|------|
| `animateToRegion` | ✅ |
| `animateCamera` / `setCamera` | ✅ |
| `getCamera` / `getMapBoundaries` | ✅(Promise) |
| `pointForCoordinate` / `coordinateForPoint` | ✅(Promise) |
| `fitToCoordinates` / `fitToElements` / `fitToSuppliedMarkers` | ✅,逐边 `edgePadding` |
| `takeSnapshot` | ✅,返回 `file://` uri 或 base64;`region` 入参接受但忽略(取当前视口) |
| `setMapBoundaries` | ✅ |
| `getMarkersFrames` | ✅ |
| `setNativeProps` | ❌ | Fabric 用 state,无此 API(也对应 RNM 旧架构遗产) |

## Marker 命令 / 事件

| API | 状态 |
|------|------|
| `showCallout` / `hideCallout` / `redrawCallout` | ✅ |
| `redraw` | ✅(custom view marker 重新栅格化)|
| `animateMarkerToCoordinate` | ✅ |
| `onPress` / `onSelect` / `onDeselect` / `onCalloutPress` | ✅ |
| `onDragStart` / `onDrag` / `onDragEnd` | ✅ |
| `tracksViewChanges` | ✅ |

## AnimatedRegion / Animated.MapView

| API | 状态 |
|------|------|
| `AnimatedRegion(...)` + `setValue` / `setOffset` / `addListener` | ✅(JS 实现)|
| `Animated.timing/spring/decay` | ✅ |
| `MapView.Animated` / `Animated.createAnimatedComponent(MapView)` | ✅ |
| AnimatedRegion 驱动地图 | ✅ rAF 合帧,降级到 `animateToRegion` |

## Provider

| Provider | 状态 |
|----------|------|
| `provider="amap"` | ✅ |
| `provider="baidu"` | ⏸ 规划中,API 形状已预留 |
| `provider="tencent"` | ⏸ 规划中 |
| `provider="google"` | ❌ 不在范围(本库定位中国 provider)|

## 平台说明

- **Android**:`minSdkVersion 24`,`targetSdkVersion 36`。Heatmap 需 host `android.enableJetifier=true`。
- **iOS**:Apple Silicon 模拟器需在 Podfile `post_install` 给所有 pod 排除 arm64(AMap framework 无 arm64-sim 切片;真机 arm64 不受影响)——详见 README 与 [CODE_REVIEW_FINDINGS.md](CODE_REVIEW_FINDINGS.md)。
