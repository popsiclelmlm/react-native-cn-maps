# M3 设计:Marker → React-children host component 模型

> 对应 ROADMAP「M3 — Marker 切换为 React-children 模型 + 进阶能力」。
> 这是整个项目**最重的一次 native 架构改动**,M4(Callout)/M5(Polyline/Polygon/Circle)都依赖这里定下的子视图方案,所以本文先把架构钉死,再切 PR。

---

## 1. 现状与目标

### 现状(M2 结束时)
- `<Marker>` 是哨兵 stub:`() => null` + `__MAP_MARKER` 标记([src/MapMarker.tsx](../src/MapMarker.tsx))。
- `<MapView>` 在 [src/MapView.tsx](../src/MapView.tsx) 里 `React.Children.forEach` 把 marker **序列化成 `markers` 数组 prop**,传给唯一的 `RNMapsMapView` Fabric 组件。
- native 端([ios/RNMapsMapView.mm](../ios/RNMapsMapView.mm) / [android/.../MapView.kt](../android/src/main/java/com/cnmaps/MapView.kt))diff 这个数组,增删 annotation。
- marker 点击走 **map 级** `onMarkerPress`,按 `identifier` 在 JS 的 `markerHandlers` ref 里反查回调。

### 目标(M3)
- `<Marker>` 变成真正的 `codegenNativeComponent('RNMapsMarker')`,作为 `<MapView>` 的 **Fabric 子 host component**。
- 子视图**不进入普通 RN 视图树渲染**:挂载/卸载时把自己注册/反注册到父地图的 `MAMapView` / `AMap` 上(RNM 自身的做法)。
- 每个 marker 自己持有 props、自己发事件、自己暴露 ref 命令。
- 支持进阶 props、drag/select 事件、ref 命令、以及 `<Marker>{children}</Marker>` 自定义 React 内容(offscreen → bitmap → icon)。

**公开 API 不变**(`<MapView><Marker coordinate=… /></MapView>` 还是这样写),变的是内部从「数组 prop」换成「子 host component」。对用户是更贴近 RNM 的形状,不是 break。

---

## 2. 核心架构决策:子 host component 怎么跟父地图通信

Fabric 下,子视图的挂载由**父视图的挂载钩子**驱动,两端都有切入点:

| 平台 | 挂载钩子 | 子计数对账 |
|------|----------|------------|
| iOS | `-[RCTViewComponentView mountChildComponentView:index:]` / `unmountChildComponentView:index:` | 父持有自己的注册表即可 |
| Android | `ViewGroupManager.addView(parent, child, index)` / `removeViewAt` | **必须**重写 `getChildCount` / `getChildAt` |

`RNMapsMarker` 子视图本身是一个真实 native view 实例(codegen 生成),但我们**拦截它**:不让它作为普通 overlay 子 view 渲染,而是让它充当一个「controller」——持有 marker 的 props/state,以及它在地图上创建出来的 `MAPointAnnotation` / AMap `Marker` 句柄。

> 这正是 react-native-maps 新架构的做法,经过验证,照搬。

### 关键约束
- **iOS**:父 `RNMapsMapView` 的 `contentView` 是 `MAMapView`。marker 子 view 绝不能 `addSubview` 到 contentView(否则会盖在地图上)。重写 `mountChildComponentView` 时对 marker **不调用 super**,子 view 就永不进入 UIView 层级。
- **Android**:`MapView` 是 `FrameLayout`。marker 子 view 不能真的 `addView` 进布局,但 Fabric 的 `SurfaceMountingManager` 会调 `getChildCount`/`getChildAt` 来 diff,所以 `MapView` 要**自己维护一个 feature 列表**并通过 manager 暴露给 Fabric。Manager 从 `SimpleViewManager` 升级为 **`ViewGroupManager<MapView>`**。

### 事件路由
AMap 的回调发生在 **map delegate** 上(不是 marker 上)。所以父地图收到回调后,要按 annotation/marker 句柄反查到对应的子 marker view,再让它发事件:
- 父持有 `annotation/marker → RNMapsMarker view` 的映射(iOS `NSMapTable`,Android `HashMap`,或直接 `marker.object = view`)。
- `didSelectAnnotationView` / `onMarkerClick` → 找到子 view → 调 `view.emitPress()` / `emitSelect()`。

---

## 3. Codegen spec(新增 `RNMapsMarker`)

新增 [src/MarkerNativeComponent.ts](../src/MarkerNativeComponent.ts):

- `codegenNativeComponent<NativeProps>('RNMapsMarker')`
- 在 [package.json](../package.json) `codegenConfig.ios.components` 里加 `"RNMapsMarker": { "className": "RNMapsMarker" }`(Android 自动生成 `RNMapsMarkerManagerInterface` + delegate)。
- 结构体尽量**扁平化**(沿用 M2 经验:codegen 对嵌套 object prop 不友好):`coordinate` 拆成 `latitude`/`longitude`;`anchor`/`centerOffset`/`calloutAnchor` 用 `{x,y}` struct(codegen 支持简单 Point struct,M2 已验证)。

### Props(codegen 层)
| prop | 类型 | 备注 |
|------|------|------|
| `identifier` | string | 路由 & fit 用 |
| `latitude`/`longitude` | Double | 由 JS 转成 gcj02 |
| `title`/`description` | string? | callout 标题/副标题 |
| `pinColor` | ColorValue? | 默认 pin 染色 |
| `image` | string? | JS 端 `resolveAssetSource` 后的 uri |
| `anchor`/`centerOffset`/`calloutAnchor` | Point? | |
| `opacity` | Double (default 1) | |
| `rotation` | Double (default 0) | |
| `flat` | bool | 贴地 vs 始终朝向相机 |
| `draggable` | bool | |
| `zIndex` | Double | |
| `tracksViewChanges` | bool (default true) | 控制自定义内容是否重绘 |
| `tracksInfoWindowChanges` | bool (default false) | |

### Events(DirectEventHandler,payload 统一带 `identifier` + `coordinate` + `position`)
`onPress` / `onSelect` / `onDeselect` / `onCalloutPress` / `onDragStart` / `onDrag` / `onDragEnd`。

### Commands(`codegenNativeCommands`)
`showCallout` / `hideCallout` / `redrawCallout` / `redraw` / `animateMarkerToCoordinate(latitude, longitude, duration)`。

---

## 4. JS 层

### 4.1 坐标系 Context(新增 [src/MapContext.ts](../src/MapContext.ts))
现在 marker 独立了,但它仍需知道 MapView 的 `coordinateSystem` 才能把 WGS-84/bd09 转成 native 要的 gcj02。方案:**React Context**。
```ts
export const MapCoordinateSystemContext =
  React.createContext<CoordinateSystem>('gcj02');
```
- `MapView` 用 `<MapCoordinateSystemContext.Provider value={coordinateSystem}>` 包住 children。
- `Marker`(以及 M5 的 Polyline/Polygon/Circle)`useContext` 拿到坐标系,转换后再喂给 native。
- 这是**为 M5 预留**的统一入口,符合「坐标转换前置到 JS 层」的全局原则。

### 4.2 `MapMarker.tsx`(重写)
- 从 stub 换成包裹 `RNMapsMarkerNativeComponent` 的真实组件;保留 `__MAP_MARKER` 标记 + `Marker.Animated` 以兼容现有识别逻辑。
- 用 context 转换 `coordinate` → gcj02 → 拆成 lat/lng。
- `image`/`icon` 用 `Image.resolveAssetSource` 解析成 uri 字符串传 native。
- 每个 marker 直接绑自己的 `onPress`/`onSelect`/…(native 已带 identifier,JS 直接转 RNM 事件形状,坐标用 context 反转回用户坐标系)。
- `useImperativeHandle` 暴露 `showCallout`/`hideCallout`/`redrawCallout`/`redraw`/`animateMarkerToCoordinate`,内部走 `Commands`。

### 4.3 `MapView.tsx`(改造)
- **删掉** `React.Children` 序列化成 `markers` 的逻辑、`markerHandlers` ref、map 级 `onMarkerPress` 处理。
- 改为把 `children` 包在 `MapCoordinateSystemContext.Provider` 里,**直接作为 native `RNMapsMapView` 的 children 渲染**,让它们作为 native 子视图挂载。
- codegen spec [src/MapViewNativeComponent.ts](../src/MapViewNativeComponent.ts) 里删掉 `markers` prop、`NativeMarker`、`onMarkerPress`/`NativeMarkerPressEvent`。

---

## 5. iOS native

### 新增 `ios/RNMapsMarker.{h,mm}` — `RNMapsMarker : RCTViewComponentView`
- 持有 `RNMapsMarkerAnnotation *_annotation`(`MAPointAnnotation` 子类,带 `identifier` + 回指 `__weak RNMapsMarker *view`)。
- `updateProps`:把 coordinate/title/pinColor/opacity/rotation/… 落到 annotation;若已在地图上且坐标变了就更新 `annotation.coordinate`。
- `- (void)addToMap:(MAMapView *)map` / `removeFromMap`:由父调用,负责 `addAnnotation` / `removeAnnotation` 并在父注册表登记。
- `handleCommand:args:` → `showCallout` = `[map selectAnnotation:_annotation animated:YES]`,`hideCallout` = `deselectAnnotation`,`animateMarkerToCoordinate` 用 `UIView`/`CADisplayLink` 插值。
- 自定义内容:有 RN children 时,用 `UIGraphicsImageRenderer` + `[self.layer renderInContext:]` **离屏**栅格化(无需在 window 里),结果设给 annotation view 的 `image`;`tracksViewChanges=YES` 时在 `layoutSubviews` 重绘,置 NO 冻结。

### `RNMapsMapView` 改造
- 重写 `mountChildComponentView:index:`:`isKindOfClass:RNMapsMarker` → `[marker addToMap:_mapView]` + 登记;否则 `super`。
- 重写 `unmountChildComponentView:index:`:marker → `removeFromMap` + 注销;否则 `super`。
- 父持有 `NSMapTable<MAAnnotation*, RNMapsMarker*>`。
- delegate:
  - `viewForAnnotation:` → 有自定义 image 用 `MAAnnotationView`+image,否则 `MAPinAnnotationView`+pinColor。
  - `didSelectAnnotationView:` → 反查 marker → `emitPress` + `emitSelect`;`didDeselect` → `emitDeselect`。
  - `annotationView:didChangeDragState:` → `emitDragStart/Drag/DragEnd`。
  - callout 点击 → `emitCalloutPress`。
- `prepareForRecycle`:清空注册表(marker 自己回收时 `removeFromMap`)。

---

## 6. Android native

### `MapViewManager`:`SimpleViewManager` → **`ViewGroupManager<MapView>`**
- 重写 `addView(parent, child, index)`:`child is MarkerView` → `parent.addFeature(child, index)`(提取 `MarkerOptions`、`aMap.addMarker`、登记映射、`marker.object = child`),**不调用 super**(不进 FrameLayout)。否则 super。
- 重写 `removeViewAt(parent, index)` / `removeView`:marker → 从 AMap 移除 + 注销。
- 重写 `getChildCount` / `getChildAt`:返回 `MapView` 自己维护的 feature 列表(**Fabric 对账必须**,签名不对会 crash「view not found」)。

### `MapView.kt` 改造
- 新增 `private val features = ArrayList<View>()`,`addFeature/removeFeature`。
- 删掉 `setMarkers` 数组路径、map 级 `MarkerPressEvent`。
- `setOnMarkerClickListener` → 用 `marker.object as MarkerView` 反查 → `markerView.emitPress()`;`setOnMarkerDragListener` → drag 事件路由;`setOnInfoWindowClickListener` → `onCalloutPress`。

### 新增 `MarkerView.kt`(`FrameLayout` 子类) + `MarkerManager`(`ViewGroupManager<MarkerView>` 实现 `RNMapsMarkerManagerInterface`)
- `MarkerView` 持有当前 props + AMap `Marker` 句柄 + 自定义内容 children。
- props → `MarkerOptions`/`Marker`:position、icon(pinColor `defaultMarker(hue)` 或栅格化 bitmap)、anchor、flat、rotateAngle、alpha、zIndex、draggable、title/snippet。
- 自定义内容:measure+layout+`draw(Canvas)` 到 `Bitmap` → `marker.setIcon(BitmapDescriptorFactory.fromBitmap(bmp))`;`tracksViewChanges` 控制重绘节流。
- 命令:`showCallout` = `marker.showInfoWindow()`,`hideCallout` = `hideInfoWindow()`,`animateMarkerToCoordinate` = position 属性动画,`redraw` = 重新栅格化。
- **`MapsPackage.kt` 注册 `MarkerManager`**(加进 `createViewManagers` 列表)。

---

## 7. PR 切分(每个 PR 都可独立编译/演示)

| PR | 范围 | 风险 |
|----|------|------|
| **M3 PR-1 — 子 host component 架构 spike** | 只带**最小 prop 集**(coordinate/title/description/pinColor/draggable)+ `onPress`。落地三层:codegen `RNMapsMarker`、iOS `mount/unmountChildComponentView`、Android `ViewGroupManager` + `getChildCount/At` + 事件路由。MapView 从「数组 prop」切到「children」,删掉旧 `markers` 路径。**行为与 M2 marker 完全一致,但已是真 host-component 架构。** | 🔴 最高(先把最难的钉死,拿 M2 行为做基线对照) |
| **M3 PR-2 — 静态外观 props** | image/icon(asset 解析 + bitmap)、anchor、centerOffset、zIndex、flat、opacity、rotation、calloutAnchor。 | 🟡 |
| **M3 PR-3 — 自定义 React 内容 marker** | `<Marker>{children}</Marker>` 离屏栅格化 → icon,`tracksViewChanges`/`tracksInfoWindowChanges`。 | 🟡(栅格化时机/性能) |
| **M3 PR-4 — drag/select 事件 + 命令** | onSelect/onDeselect/onDragStart/onDrag/onDragEnd/onCalloutPress;showCallout/hideCallout/redrawCallout/animateMarkerToCoordinate/redraw。 | 🟢 |
| **M3 PR-5 — marker gallery 演示页 + 测试** | 默认 pin / 彩色 pin / image marker / 自定义 React 视图 marker / 可拖拽 marker;加快照/单测。 | 🟢 |

**建议 PR-1 单独、慎重地做**——它是 M4/M5 的地基,值得拿 M2 已知正确的 marker 行为当回归基线。

---

## 8. 风险 & 待确认

1. **Android `getChildCount/getChildAt` 契约**:必须与 Fabric `SurfaceMountingManager` 的对账精确一致,否则运行期 crash。需对照 react-native-maps 现版 `MapManager`/`MapMarkerManager` 的实现细节。
2. **iOS 离屏栅格化**:marker view 不在 window 里,`drawViewHierarchyInRect:` 不可靠,必须用 `layer renderInContext:`;还要解决「children 布局完成后才能截图」的时机(RNM 用 tracksViewChanges 循环)。
3. **`tracksViewChanges` 默认值**:RNM 默认 `true`(每帧重绘,性能差但行为对),我们沿用 `true` 并在文档警告——大量 marker 时建议置 `false`。
4. **回收/生命周期**:Fabric `prepareForRecycle`(iOS)、Android view 复用时必须把 annotation/marker 从地图摘掉,否则泄漏/残留。
5. **坐标 Context 与 Animated**:M10 的 `AnimatedRegion`/animated marker 仍走 context 转换;先确认 `Animated.createAnimatedComponent(Marker)` 在 host-component 化之后还能正常透传 props。
6. **z-order**:marker 与未来 overlay(M5)的层级关系,本期先不管,但 spec 里 `zIndex` 先接住。
7. **AMap 自定义 callout 能力差异**:本期 callout 仍用系统 InfoWindow,真正的 `<Callout>` 自绘留给 M4——M3 的 `tracksInfoWindowChanges` 先接 prop 不强求效果。

---

## 9. 一句话总结

M3 = 把 marker 从「父地图的一个数组 prop」升级成「父地图拦截挂载的真子 host component」。**先用 PR-1 把三层挂载/卸载/事件路由的架构钉死(行为对齐 M2 做回归),再按外观→自定义内容→交互事件→演示页逐层加厚。** 这套子视图拦截方案(iOS 不入视图树 / Android `ViewGroupManager` 自管 child 列表)是 M4 Callout、M5 覆盖物共用的地基。
