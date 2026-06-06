# 代码评审 findings(待统一修复)

> 全工程逐文件走读产出的问题清单。先记录、后统一修复。修复后把状态改为 ✅,并在对应 PR/commit 注明。

## 图例

- 🔴 **correctness** — 真 bug / 行为错误
- 🔵 **architecture** — 架构 / 设计决策
- 🟡 **cleanup** — 死代码 / 冗余 / 一致性
- ⚪ **minor** — 可选优化(精度、性能、可读性)

状态:⬜ 待修 · 🚧 修复中 · ✅ 已修

---

## A 组:JS 基础层

| ID | 级别 | 文件 | 问题 | 建议修法 | 状态 |
|----|------|------|------|----------|------|
| A1 | 🟡 cleanup | `src/_warnings.ts` | `useWarnNotImplemented` / `__resetWarningsForTests` 已无任何调用方(M11–M18 把 6 个 stub 全转真实现),整文件死代码 | 删除 `src/_warnings.ts` | ⬜ |
| A2 | 🔴 correctness | `src/coordinate.ts` | `toProviderCoordinate/fromProviderCoordinate` 用 `=== 'wgs84'` 二元判断,`bd09` 源坐标落入 `else` 被**静默当作 gcj02**,错位数百米。`CoordinateSystem` 类型声明了 3 种但只处理 2 种 | 补 `bd09ToGcj02 / gcj02ToBd09`(BD-09↔GCJ-02 标准公式),把两个函数改成对**源坐标系**的显式三分派;或至少对 `bd09` 显式 `__DEV__` 警告,避免静默错位 | ⬜ |
| A3 | ⚪ minor | `src/coordinate.ts` | `gcj02ToWgs84` 用一次"减法粗反解"(`原值*2 - 正解`),误差约 1–2 米 | 如需更高精度可改 2–3 次迭代逼近;一般地图够用,可不改 | ⬜ |

### A-arch:多 provider 坐标系规约(挂 M8 百度)

| ID | 级别 | 范围 | 决策 | 状态 |
|----|------|------|------|------|
| A4 | 🔵 architecture | `coordinate.ts` + M8 百度 | 当前"JS 转 gcj02 下发、native 恒收 gcj02"是**正确且可延续**的方向(高德/腾讯原生即 gcj02;百度原生是 **bd09**,但可用 `SDKInitializer.setCoordType(CoordType.GCJ02)`(Android)/ iOS 等价全局设置让其按 gcj02 解释)。**定为统一规约**:native 层恒收发 GCJ-02,各 provider 负责让 SDK 以 gcj02 解释。需在 M8 文档写明 + 百度 provider 初始化时设置 | ⬜ |

> 注:A2(用户源侧 bd09 转换)与 A4(provider 输出侧)是**两件独立的事**——A4 解决"发给哪家 SDK",A2 解决"用户给的数据是 bd09 时先转成 gcj02"。两者都要做。

---

## B 组:JS 核心(MapView / Marker / AnimatedRegion)

| ID | 级别 | 文件 | 问题 | 建议修法 | 状态 |
|----|------|------|------|----------|------|
| B1 | 🔴 correctness | `src/MapView.tsx` + `ios/RNMapsMapView.mm` | 命令 Promise 生命周期不健全:`pendingRequests` resolver **卸载不清理 / 无超时 / 无 reject**,native 不回传则永久挂起 + 泄漏。iOS `takeSnapshot` 回调 `if (image == nil) return;` 截图失败不发结果 → JS 永挂 | ① `query` 加卸载 `useEffect` cleanup,把 pending 全 reject;② 可选超时 reject;③ iOS 截图 nil 分支也 `emitCommandResult` 空 uri | ⬜ |
| B2 | 🔴 correctness | `src/MapView.tsx` | `query` 中 `nativeRef.current` 为 null 时只注册 resolver 不发送 → Promise 永挂 + 泄漏 | ref 为空时直接 reject(或 resolve 兜底)并不入 pending | ⬜ |
| B3 | ⚪ minor | `src/MapView.tsx` | `handleCommandResult` 的 `JSON.parse(data)` 未 try/catch,畸形 data 会在事件处理中抛错 | 包 try/catch,解析失败 resolve `{}` 或 reject 对应请求 | ⬜ |
| B4 | 🔵 architecture | `src/MapView.tsx` | `provider` 给 native 写死 `'amap'`,用户传的 provider 仅用于告警 | 接腾讯/百度(M8/M9)时改为透传真实 provider | ⬜ |
| B5 | ⚪ minor(perf) | `src/AnimatedRegion.ts` + `src/MapView.tsx` | `addListener` 给 4 个 Animated.Value 各挂监听,一帧内全变 → 回调(进而 `animateToRegion`)每帧约触发 4 次,原生命令 4× 冗余 | 用 rAF 合并一帧多次回调,或只监听单个值触发快照 | ⬜ |
| B6 | ⚪ minor | `src/AnimatedRegion.ts` | `__getValue` 读私有 `_value`,且不含 `setOffset` 的 offset → `setOffset` 后 `toJSON()`/快照偏移。跨 RN 版本脆弱 | 低优先;如需正确 offset 可 `addListener` 缓存最新值或叠加 offset | ⬜ |
| B7 | ⚪ minor(perf) | `src/MapMarker.tsx` | 事件 handler 每次 render 新建内联闭包(`onPress={(e)=>...}`),marker 多时有 diff 开销 | RN 习惯写法,可不改;如需可 useCallback 化 | ⬜ |

## C 组:JS 覆盖物/瓦片门面

_(待走读)_

## D 组:JS web stubs

| ID | 级别 | 文件 | 问题 | 建议修法 | 状态 |
|----|------|------|------|----------|------|
| D1 | 🟡 cleanup | `src/*.web.tsx` + vite/react-native-web | web stub 覆盖不全(6/12 组件)、`MapView.web` handle 不全;且无 web 需求 | **整层移除**:删 6 个 `*.web.tsx` + `example/{index.html,vite.config.mjs}` + 两个 package.json 的 web 脚本/依赖 + ROADMAP M7 标撤 | ✅ |

## E 组:Android 核心(MapView.kt)

> 整体质量高:lifecycle 完整、事件 coalesce 合理、坐标转 dp、marker 事件路由、InfoWindowAdapter 接 Callout。无泄漏/崩溃级问题。

| ID | 级别 | 文件 | 问题 | 建议修法 | 状态 |
|----|------|------|------|----------|------|
| E1 | ⚪ minor(correctness) | `android/.../MapView.kt` | `isGesture` 在 ACTION_DOWN 置真,仅 `onCameraChangeFinish` 复位;纯点击后会粘住 → 下次(程序化)相机变化误报 `isGesture=true` | ACTION_UP/CANCEL 复位,或只在 MOVE 置真 | ⬜ |
| E2 | ⚪ minor(behavior) | `android/.../MapView.kt` | `setOnMarkerClickListener` 返回 `false` → AMap 默认把地图居中到 marker,RNM 不会 | 返回 `true` 并按需手动 `showInfoWindow()` | ⬜ |
| E9 | 🟡 cleanup(perf/ANR) | `android/.../MapView.kt` | `takeSnapshotResult` 在主线程回调里同步 `Bitmap.compress` + 写盘,大图可能卡顿/ANR | 压缩+写盘移到后台线程,完成再 `dispatchCommandResult` | ⬜ |
| E4 | ⚪ minor(parity) | `android/.../MapView.kt` | `fitToCoordinates` 的 edgePadding 取四边最大值(单一 padding) | 改用 `CameraUpdateFactory.newLatLngBoundsRect(bounds,l,r,t,b)` 逐边 | ⬜ |
| E6 | ⚪ minor(semantic) | `android/.../MapView.kt` | `showsPointsOfInterest` → `showMapText` 会隐藏所有文字标注,非仅 POI | 文档说明;AMap 无 POI-only 开关 | ⬜ |
| E8 | ⚪ info | `android/.../MapView.kt` | `addFeature` 未知子 view `else->return` 不计入 features,理论上 getChildCount 可能不一致 | 实际只 mount 已知类型,低风险;可加断言 | ⬜ |

## F–G 组:Android marker/覆盖物/瓦片

| ID | 级别 | 文件 | 问题 | 建议修法 | 状态 |
|----|------|------|------|----------|------|
| F3 | 🟡 cleanup(parity/correctness) | `MapView.kt` + `PolylineView.kt` / `PolygonView.kt` | Polyline/Polygon 的 `emitPress()` **从未被调用**——configureMap 无 `setOnPolylineClickListener`/polygon 点击监听,`onPress`/`tappable` 在 Android 上不触发(M5_DESIGN 却声称已支持,文档与实现不符;emitPress 为死方法) | 给 PolylineView 的 polyline 设 `object=this` + configureMap 加 `setOnPolylineClickListener` 路由;Polygon 多数 AMap 版本无点击回调→文档化 best-effort | ⬜ |
| F4 | ⚪ minor(parity) | `PolygonView.kt` / `PolygonManager.kt` | `holes` 在 Android 静默忽略(`setHoles` no-op),M5_DESIGN 声称支持 | 新版 AMap `PolygonOptions.addHoles()` 可实现;否则文档明确不支持 | ⬜ |
| F1 | ⚪ minor(perf) | `MarkerView.kt` | 自定义内容每次 `Bitmap.createBitmap` 不 recycle 旧 `customBitmap`,`tracksViewChanges` 频繁重绘 GC 压力 | 替换前 recycle 旧位图;detach 时也 recycle | ⬜ |
| F2 | ⚪ minor(robustness) | `MarkerView.kt` / `OverlayView.kt` / `UrlTileView.kt` / `HeatmapView.kt` | 网络图/瓦片解码用 `URL.openStream()` 无超时,坏网络挂住线程;每张图新建 `Thread`(无线程池) | 设连接/读超时;考虑共享线程池 | ⬜ |

## H 组:iOS 核心(RNMapsMapView.mm)

> 质量高,和 Android 对称;`prepareForRecycle`/`dealloc` 处理到位;`_isGesture` 比 Android 更干净(无粘住),点 marker 不重定位(无 Android E2 问题)。

| ID | 级别 | 文件 | 问题 | 建议修法 | 状态 |
|----|------|------|------|----------|------|
| H-arch | 🔵 architecture(风险) | 全部 `ios/*.mm` | iOS 从未真机编译:命令选择器需匹配 codegen `RCTRNMaps*ViewProtocol`;M11–M18 依赖的 AMap iOS 符号(`MAGroundOverlay(Renderer)`/`MAMultiColoredPolyline(Renderer)`/`MAHeatMapTileOverlay/Node/Gradient`/`MATileOverlay.URLForTilePath`)全靠推导 | 首次 `pod install`+编译,按报错逐个修(见 VERIFICATION_CHECKLIST iOS 段) | ⬜ |
| H1 | ⚪ minor | `ios/RNMapsMapView.mm` | 显示/手势开关每次 updateProps 无条件重设(无 old≠new 守卫),`showsUserLocation` 反复设可能反复触发定位 | 加 old≠new guard,像 mapType/zoom 那样 | ⬜ |
| H2 | ⚪ info | `ios/RNMapsMapView.mm` | `showsLabels`←`showsPointsOfInterest` 控制所有标注非仅 POI(同 Android E6) | 文档化 best-effort | ⬜ |

## I–J 组:iOS marker/覆盖物/瓦片

_(待走读)_

## K 组:example + 配置(podspec / gradle)

_(待走读)_
