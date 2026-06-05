# M4 设计:Callout(气泡)+ CalloutSubview

> 对应 ROADMAP「M4 — Callout(气泡)+ CalloutSubview」。复用 M3 钉下的「子 host component 拦截」地基,只是把拦截再下沉一层:`MapView → Marker → Callout`。

## 1. 目标

- `<Marker><Callout>…</Callout></Marker>` 直接工作:Callout 的 React 子树作为气泡内容显示。
- `tooltip` 决定是否用「纯自绘」气泡(无系统外框)。
- `onPress`:Callout 整体可点(同时触发 `<Callout onPress>` 与 `<Marker onCalloutPress>`)。
- `<CalloutSubview>`:本期渲染内容,**子项独立点击 best-effort 不支持**(Android InfoWindow 是位图快照,iOS 自绘气泡也按整体路由),文档说明限制,整体走 Callout `onPress`。

## 2. 架构:Callout 作为 Marker 的子 host component

新增 codegen `RNMapsCallout`(`<Marker>` 的子 host component)。Marker 像「父地图拦截 marker」一样**拦截 callout 子视图**:把它从「marker 图标内容」里摘出来,只在气泡里用。

| 平台 | 气泡显示方式 | 点击 |
|------|--------------|------|
| iOS | 选中时把 callout 子树**离屏栅格化**成 `UIImage`,放进 annotation view 上方的 `UIImageView`;`canShowCallout=NO` 自己管 | image view 上加 tap 手势 |
| Android | `AMap.setInfoWindowAdapter` 的 `getInfoWindow` 返回 callout 子视图(AMap 直接量算/绘制);callout 必须**无 parent** | `setOnInfoWindowClickListener` |

### 关键:callout 必须脱离 marker 的图标内容
- **iOS**:marker 的 `mountChildComponentView` 遇到 `RNMapsCallout` **不调用 super**(不作为 marker 子视图,故不进图标栅格化、不影响 marker bounds),仅存引用 `_calloutView`。
- **Android**:`MarkerManager` 用和 MapView 同样的 `ViewGroupManager` 手法:重写 `addView/getChildCount/getChildAt`,marker 维护一个 react-children 列表;callout 子项**只入列表、不入 FrameLayout**(避免「view 已有 parent」崩溃,也不进图标栅格化),普通内容仍进 FrameLayout 走 M3 图标栅格化。

### 事件
- iOS:tap 手势 → `[marker emitCalloutPress]`(已有)+ `[calloutView emitPress]`。
- Android:`onInfoWindowClick` → `markerView.emitCalloutPress()`(已有)+ `calloutView.emitPress()`。

## 3. 三层落点

- **JS**:`src/CalloutNativeComponent.ts`(`RNMapsCallout`,props `tooltip` + `onPress`);`MapCallout.tsx` 包真组件;`MapCalloutSubview.tsx` 升级成 RN `View` 透传(onPress 限制见上)。
- **iOS**:`RNMapsCallout.{h,mm}`;`RNMapsMarker` 拦截 callout、选中时呈现栅格化气泡 + tap;`RNMapsMapView` 的 `didSelect/didDeselect` 调 marker 呈现/收起。
- **Android**:`CalloutView.kt` + `CalloutManager.kt`(注册进 `MapsPackage`);`MarkerView`/`MarkerManager` 拦截 callout 子项;`MapView` 设 `InfoWindowAdapter`。

## 4. 限制(本期文档化)

- CalloutSubview 子项独立点击不支持(整体 onPress 代替)。
- 「自定义 marker 视图 + Callout 同时用」时,marker bounds 仍含 callout 区域是边角情形;最常见的「默认 pin + Callout」无此问题。
- iOS 气泡是栅格化静态图(无交互子视图);真正交互留待后续打磨。
