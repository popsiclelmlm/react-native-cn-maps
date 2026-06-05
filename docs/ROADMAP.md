# react-native-cn-maps 路线图

> 目标:对标 `react-native-maps` 的完整 API,适配国内地图 SDK(高德 / 百度 / 腾讯),让用户**只需修改 import 路径**就能完成迁移。仅适配 React Native 新架构(Fabric)。

## 进度总览

> 图例:✅ 完成 · 🚧 进行中 · ⏸ 暂缓 · ⬜ 未开始
> native 代码均已三层落地 + 过 typecheck / lint / jest / codegen schema 校验,但**尚未在真机/模拟器编译验证**(统一测试阶段进行)。

| 里程碑 | 状态 | 备注 |
|--------|------|------|
| M1 — API 表面 shim | ✅ | sentinel-stub + 全量类型 |
| M2 — MapView prop & 事件 | ✅ | 全 prop 矩阵演示页 |
| M3 — Marker host-component | ✅ | PR1-5;见 [M3_DESIGN](M3_DESIGN.md) |
| M4 — Callout + CalloutSubview | ✅ | 见 [M4_DESIGN](M4_DESIGN.md) |
| M5 — Polyline/Polygon/Circle | ✅ | 见 [M5_DESIGN](M5_DESIGN.md) |
| M6 — MapView 命令式 API | ✅ | command + onCommandResult Promise 回传 |
| M7 — Web stub | ✅ | `.web.tsx` 占位,真实 web 地图待接入 |
| M8 — 百度 provider | ⏸ | 需真实 SDK + key,留待基线测试后 |
| M9 — 腾讯 provider | ⏸ | 同 M8 |
| M10 — Animated + 文档 + CI | ✅ | `AnimatedRegion` 驱动 + [迁移文档](MIGRATION_FROM_RN_MAPS.md) |

迁移支持状态明细见 [MIGRATION_FROM_RN_MAPS.md](MIGRATION_FROM_RN_MAPS.md)。

## 现状评估(M0,已具备)

- JS 层:`MapView` + `Marker`(stub 组件,靠 `__MAP_MARKER` 哨兵识别)。
- iOS:`MAMapKit`(高德 iOS SDK)跑通 Fabric 通路。
- Android:AMap SDK 跑通 codegen `RNMapsMapViewManagerInterface`。
- Markers 当前以**序列化数组 prop** 传递(尚未做成真正的子 host view)。_（已被 M3 取代:marker 现为真正的子 host component。）_
- 坐标系:GCJ-02 ↔ WGS-84 在 JS 层完成,native 端只收 gcj02。

**已经做对的关键决策**:坐标转换前置到 JS 层;Fabric codegen 直接走 `codegenNativeComponent` + `codegenNativeCommands`。

---

## 全局架构原则(贯穿所有阶段)

1. **JS 层做 RNM 兼容门面,native 端做 SDK 适配**。所有 prop / event 名按 RNM 命名,在 JS 层映射到内部 codegen spec。
2. **多 provider 共用同一 JS 门面**。Android / iOS 各 provider 实现同一个 codegen 接口,通过 `provider` prop 在 native 层 dispatch(或编译期挑选)。
3. **每个里程碑都要有 example app 演示页 + 至少一个单测/快照**,保证不回归。
4. **任何 RNM 在国内 SDK 上语义不能 1:1 实现的 prop**,JS 层 best-effort 映射 + `__DEV__` warning,不改 API 形状。

---

## M1 — API 表面 shim(没有 native 也能编译通过) ✅

**目标**:让一个用 react-native-maps 的项目把 import 改成 `react-native-cn-maps` 后,**TypeScript 立刻通过编译**,运行时即使功能没实现也只是 warn,不崩。

- 顶层 re-export 补齐:`PROVIDER_DEFAULT` / `PROVIDER_GOOGLE`(都映射到当前 provider 或 default)、`MAP_TYPES`、`Geojson`、`Heatmap`、`Overlay`、`Callout`、`CalloutSubview`、`UrlTile`、`WMSTile`、`LocalTile`、`AnimatedRegion`、`Animated` 命名空间。
- 全部用与 M0 `Marker` 相同的 sentinel-stub 模式先占位(渲染 `null`,带 `__MAP_*` 标记)。
- 类型对齐:逐一对照 `@types/react-native-maps` 的导出,把 `MapViewProps`、`MarkerProps`、`PolylineProps`、`PolygonProps`、`CircleProps`、`CalloutProps`、`MapPressEvent`、`LongPressEvent`、`MarkerDragEvent`、`UserLocationChangeEvent`、`Camera`、`EdgePadding` 等类型补全(暂不实现也要先有 type)。
- `__DEV__` 下,未实现组件 mount 时 console.warn 一次。
- 单测:`tsc` 在示例 RNM 用法片段上必须通过。

**交付**:用户改 import 后 `tsc` + bundle 零报错。

---

## M2 — MapView 基础 prop & 事件全量对齐 ✅

**目标**:`<MapView>` 本身的所有 RNM prop 都接住,常用事件全发。

- 新增 props:`mapType`(`standard|satellite|hybrid|terrain|none|mutedStandard`)、`camera`(heading / pitch / zoom / altitude / center)、`initialCamera`、`minZoomLevel`、`maxZoomLevel`、`mapPadding`、`customMapStyle`、`userInterfaceStyle`、`showsCompass`、`showsScale`、`showsTraffic`、`showsBuildings`、`showsIndoors`、`showsMyLocationButton`、`showsPointsOfInterest`、`loadingEnabled` & 相关、`toolbarEnabled`(Android)、`liteMode`(Android)、`kmlSrc`、`tintColor`。
- 新增事件:`onMapReady`、`onMapLoaded`、`onPress`(map tap)、`onLongPress`、`onPanDrag`、`onPoiClick`、`onUserLocationChange`、`onDoublePress`。
- Codegen spec(`MapViewNativeComponent.ts`)同步扩展;native 端 iOS / Android 分别落到 AMap 对应 API(没有的 prop 在 native 端忽略,JS 层 `__DEV__` warn)。
- `camera` ↔ `region` 两种摄像头表示在 native 端归一化。
- example app 增加一个"全 prop 矩阵"演示页。

---

## M3 — Marker 切换为 React-children 模型 + 进阶能力 ✅

**目标**:把 markers 从"序列化数组 prop"改造成**真正的 Fabric child host components**,以支持自定义 marker view、callout、drag 事件。

这是最重的一步,影响 native 架构,建议单独迭代。

- JS 层:`<Marker>` 改为真的 `codegenNativeComponent('RNMapsMarker')`,作为 `<MapView>` 的子视图。
- iOS:`RNMapsMarker` 作为 `RCTViewComponentView` 子类,在 `mountChildComponentView` / `unmountChildComponentView` 时把自己注册 / 反注册到父 `RNMapsMapView` 的 `MAMapView` 上(典型做法:overlay view 不参与 native 视图树渲染,但持有 annotation)。
- Android:类似思路,`MapView` 重写 `addView` 拦截 `RNMapsMarker` 子 view,把 `MarkerOptions` 提交给 `AMap`,marker 视图本身脱离普通布局。
- 进阶 props 全部接住:`image`、`icon`、`anchor`、`centerOffset`、`calloutAnchor`、`tracksViewChanges`、`tracksInfoWindowChanges`、`zIndex`、`flat`、`opacity`、`rotation`、`draggable`。
- 事件:`onPress`、`onSelect`、`onDeselect`、`onCalloutPress`、`onDragStart`、`onDrag`、`onDragEnd`。
- Marker ref 命令(codegen commands):`showCallout`、`hideCallout`、`redrawCallout`、`animateMarkerToCoordinate`、`redraw`。
- 自定义 marker 内容:`<Marker>{children}</Marker>` 把 React 子树 render 到一个 offscreen view,转 bitmap 后作为 icon(典型 RNM 实现思路);`tracksViewChanges` 控制何时重新 rasterize。
- example app 增加 marker gallery 页:默认 pin、彩色 pin、image marker、自定义 React 视图 marker、可拖拽 marker。

---

## M4 — Callout(气泡)+ CalloutSubview ✅

**目标**:让 `<Marker><Callout>...</Callout></Marker>` 这个用得最多的组合直接工作,以及 `<CalloutSubview onPress>` 的部分点击。

- iOS:用 AMap 自定义 callout view(`MAAnnotationView` 的 `detailCalloutAccessoryView` 或自绘 popover);RN 子树 → offscreen render → 图片 / 自定义 view。
- Android:AMap 的 `InfoWindowAdapter` 拿到 React 子树位图后塞进 info window。
- `tooltip` prop 决定是否用纯自绘 callout(无系统外框)。
- 事件 `onPress` 在 callout 整体或 CalloutSubview 上路由(Android 上 InfoWindow 子点击不原生支持,要 best-effort 转 marker click + 命中测试,文档说明限制)。

---

## M5 — 覆盖物:Polyline / Polygon / Circle ✅

**目标**:三大几何覆盖物按 RNM API 接入。

- JS:`<Polyline>` / `<Polygon>` / `<Circle>` 各自 codegen 一个子 host component,挂在 `<MapView>` 下。
- props:`coordinates`、`strokeColor`、`strokeWidth`、`strokeColors`(渐变 polyline)、`fillColor`、`lineDashPattern`、`lineCap`、`lineJoin`、`miterLimit`、`geodesic`、`tappable`、`zIndex`、`holes`(polygon 内孔)。
- 事件:`onPress`(`tappable=true` 时)。
- native:AMap iOS 用 `MAPolyline` / `MAPolygon` / `MACircle` + `mapView:rendererForOverlay:`;Android 用 `aMap.addPolyline/Polygon/Circle`。
- 坐标系按 `<MapView coordinateSystem>` 在 JS 层统一转换。
- example app:沿地铁线、围栏、范围圈三个演示。

---

## M6 — MapView 命令式 API(ref methods)全量 ✅

**目标**:RNM 用户依赖很重的 ref 命令全部可用。

- codegen commands 扩展:`animateCamera`、`setCamera`、`getCamera`(返回 Promise);`fitToElements`、`fitToSuppliedMarkers(markerIDs, options)`、`fitToCoordinates(coords, { edgePadding, animated })`、`getMapBoundaries()`、`setMapBoundaries(ne, sw)`、`pointForCoordinate(coord)`、`coordinateForPoint(point)`、`getMarkersFrames(onlyVisible)`、`setIndoorActiveLevelIndex`、`addressForCoordinate`(iOS,可选)。
- 返回值类的 API(`getCamera` 等)用 Fabric command 不太顺手;两种方案任选其一:
  - (a) 用 codegen Command + 配套 `onXxxResult` 事件 + JS 端 Promise 封装(RNM 在 Fabric 下的实际做法);
  - (b) 新增一个 TurboModule `RNMapsModule`,把"查询类"方法都放进去,view ref 传 reactTag / handle。
  - **推荐 (b)**,更干净,JS 门面对外仍然是 `mapRef.current.getCamera()`。

---

## M7 — Web stub(react-native-web) ✅

**目标**:`vite` 已经在依赖里,补一个最小可用的 web 端 fallback,至少 import 不崩、能渲染占位或 Leaflet / Mapbox / AMap-JS。

- 用 `react-native-web` platform extension(`MapView.web.tsx`),先渲染一个"地图不可用"占位 + console hint。
- 第二步选一个 web 地图(AMap JS API 最稳)接最小子集:`initialRegion` / Marker / Polyline。
- 这一阶段不强求 native 全功能对齐。

---

## M8 — 第二个 provider:百度地图 ⏸

**目标**:验证多 provider 架构。这一阶段会反向暴露设计问题,所以越早做越好。

- 新增 `coordinateSystem="bd09"` + bd09 ↔ gcj02 ↔ wgs84 三向转换。
- iOS:可选依赖 `BaiduMapAPI_*`(用户在 Podfile 里 opt-in);native 端用 `provider` prop 选择实现(运行时分发或编译期 flavor)。
- Android:可选 `com.baidu.lbsapi:*`,同上。
- podspec / build.gradle 改为按 subspec / variant 让用户**只引入自己用的 SDK**(很关键,SDK 体积大且需要 key)。
- 在 `<MapView provider="baidu">` 演示页里跑完整的 M2–M5 功能矩阵作为回归。

---

## M9 — 第三个 provider:腾讯地图 + Provider 抽象稳定 ⏸

- 同 M8,接 `TencentMap`,坐标系仍是 gcj02。
- 至此可以反过来重构 native 端的 provider 抽象层(三家都跑过之后才知道接口该怎么抽,避免过早抽象)。
- iOS:抽 `RNMapsProvider` 协议;Android:抽 `RNMapsProviderAdapter` 接口。

---

## M10 — Animated API + 收尾打磨 ✅

- `AnimatedRegion`:实现成 RNM 那种"四个 `Animated.Value` 组合"的类,`MapView` 内部识别并桥到原生(或退化为 `animateToRegion(toJSON())`)。
- 性能 & 生命周期:Fabric `prepareForRecycle`、Android `onHostPause / Resume / Destroy` 做一轮压力测试 — 切页面、横竖屏、快速 mount / unmount。
- 文档:`MIGRATION_FROM_RN_MAPS.md` 列出每个 RNM prop / event / method 的支持状态表(✅ / ⚠️ 差异 / ❌ 未实现)。
- CI:GitHub Actions 跑 lint + typecheck + jest + Android build + iOS build(模拟器)。
- 发布:`release-it` 配置已就绪,准备 0.2 / 0.3 节奏发版。

---

## 建议执行顺序

把 **M1 → M2 → M3** 看成"必须连续做完"的第一波(API shim → MapView 完整 → Marker 完整),完成后 80% 的迁移场景就能跑;之后 M4–M6 按用户反馈优先级穿插;M7–M10 看节奏。

**最关键的早期决策**:M3 的 children-as-host-components 重构。这个不做,后面所有 Marker / Polyline / Polygon / Callout 都没法按 RNM 形状落地。所以**第一个写代码的迭代里就要决定 M3 的 native 子视图方案**(倾向 iOS 子 view 不入 RN 视图树、Android 重写 `addView` 拦截,这是 RNM 自身的做法)。
