# 代码评审 findings(待统一修复)

> 全工程逐文件走读产出的问题清单。先记录、后统一修复。修复后把状态改为 ✅,并在对应 PR/commit 注明。

> ✅ **P2 清理批完成(2026-06-06)** —— A3 / B5 / B6 / E4 / E6 / E8 / F1 / F2 / H1 / H2 / K1 / K2 / K3 全部处理(B7 跳过=RN 习惯写法)。库 Kotlin 编译通过、JS 44 测试 + typecheck + lint 全绿。**剩余仅架构类**:A4(多 provider 坐标规约)、B4(provider 透传)挂未来 Baidu / Tencent 接入。

> ✅ **iOS 首次编译 + 真机/模拟器全功能验证通过(2026-06-06)** —— H-arch 关闭。bring-up 过程中发现并修复一串 iOS 库级真 bug(走读/编译都看不出,只有真跑才暴露),见下方「iOS bring-up findings」。

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
| A1 | 🟡 cleanup | `src/_warnings.ts` | `useWarnNotImplemented` / `__resetWarningsForTests` 已无任何调用方(stub 全转为真实现),整文件死代码 | 删除 `src/_warnings.ts` | ✅ 已删 |
| A2 | 🔴 correctness | `src/coordinate.ts` | `toProviderCoordinate/fromProviderCoordinate` 用 `=== 'wgs84'` 二元判断,`bd09` 源坐标落入 `else` 被**静默当作 gcj02**,错位数百米。`CoordinateSystem` 类型声明了 3 种但只处理 2 种 | 补 `bd09ToGcj02 / gcj02ToBd09`(BD-09↔GCJ-02 标准公式),把两个函数改成对**源坐标系**的显式三分派;或至少对 `bd09` 显式 `__DEV__` 警告,避免静默错位 | ✅ 已补 bd09↔gcj02 + 三分派 + 单测 |
| A3 | ⚪ minor | `src/coordinate.ts` | `gcj02ToWgs84` 用一次"减法粗反解"(`原值*2 - 正解`),误差约 1–2 米 | 如需更高精度可改 2–3 次迭代逼近;一般地图够用,可不改 | ✅ 改 3 次迭代逼近 + 亚厘米单测 |

### A-arch:多 provider 坐标系规约(挂未来 Baidu 接入)

| ID | 级别 | 范围 | 决策 | 状态 |
|----|------|------|------|------|
| A4 | 🔵 architecture | `coordinate.ts` + 百度接入 | 当前"JS 转 gcj02 下发、native 恒收 gcj02"是**正确且可延续**的方向(高德/腾讯原生即 gcj02;百度原生是 **bd09**,但可用 `SDKInitializer.setCoordType(CoordType.GCJ02)`(Android)/ iOS 等价全局设置让其按 gcj02 解释)。**定为统一规约**:native 层恒收发 GCJ-02,各 provider 负责让 SDK 以 gcj02 解释。需在百度 provider 接入文档写明 + 初始化时设置 | ⬜ |

> 注:A2(用户源侧 bd09 转换)与 A4(provider 输出侧)是**两件独立的事**——A4 解决"发给哪家 SDK",A2 解决"用户给的数据是 bd09 时先转成 gcj02"。两者都要做。

---

## B 组:JS 核心(MapView / Marker / AnimatedRegion)

| ID | 级别 | 文件 | 问题 | 建议修法 | 状态 |
|----|------|------|------|----------|------|
| B1 | 🔴 correctness | `src/MapView.tsx` + `ios/RNMapsMapView.mm` | 命令 Promise 生命周期不健全:`pendingRequests` resolver **卸载不清理 / 无超时 / 无 reject**,native 不回传则永久挂起 + 泄漏。iOS `takeSnapshot` 回调 `if (image == nil) return;` 截图失败不发结果 → JS 永挂 | ① `query` 加卸载 `useEffect` cleanup,把 pending 全 reject;② 可选超时 reject;③ iOS 截图 nil 分支也 `emitCommandResult` 空 uri | ✅ 卸载 reject + 10s 超时 + iOS 仅 state==1 处理、nil 发空 uri |
| B2 | 🔴 correctness | `src/MapView.tsx` | `query` 中 `nativeRef.current` 为 null 时只注册 resolver 不发送 → Promise 永挂 + 泄漏 | ref 为空时直接 reject(或 resolve 兜底)并不入 pending | ✅ ref 空时立即 reject |
| B3 | ⚪ minor | `src/MapView.tsx` | `handleCommandResult` 的 `JSON.parse(data)` 未 try/catch,畸形 data 会在事件处理中抛错 | 包 try/catch,解析失败 resolve `{}` 或 reject 对应请求 | ✅ 随 B1 一并加 try/catch + clearTimeout |
| B4 | 🔵 architecture | `src/MapView.tsx` | `provider` 给 native 写死 `'amap'`,用户传的 provider 仅用于告警 | 接腾讯/百度时改为透传真实 provider | ⬜ |
| B5 | ⚪ minor(perf) | `src/AnimatedRegion.ts` + `src/MapView.tsx` | `addListener` 给 4 个 Animated.Value 各挂监听,一帧内全变 → 回调(进而 `animateToRegion`)每帧约触发 4 次,原生命令 4× 冗余 | 用 rAF 合并一帧多次回调,或只监听单个值触发快照 | ✅ MapView 消费侧 rAF 合帧(保留 addListener 同步语义,测试约束) |
| B6 | ⚪ minor | `src/AnimatedRegion.ts` | `__getValue` 读私有 `_value`,且不含 `setOffset` 的 offset → `setOffset` 后 `toJSON()`/快照偏移。跨 RN 版本脆弱 | 低优先;如需正确 offset 可 `addListener` 缓存最新值或叠加 offset | ✅ `__getValue` 改读 `_value + _offset`(修正 setOffset 后快照) |
| B7 | ⚪ minor(perf) | `src/MapMarker.tsx` | 事件 handler 每次 render 新建内联闭包(`onPress={(e)=>...}`),marker 多时有 diff 开销 | RN 习惯写法,可不改;如需可 useCallback 化 | ⏭️ 跳过(RN 习惯写法,收益小) |

## C 组:JS 覆盖物/瓦片门面

> 已走读:Polyline/Polygon/Circle/Callout/CalloutSubview/Overlay/UrlTile/LocalTile/WMSTile/Heatmap/Geojson 门面均为已审的同一套模式(context 转坐标 + JSON 跨界 + sentinel)。`CalloutSubview.onPress` 为文档化 no-op(callout 整体栅格化的限制)。**无新增独立 finding**(坐标系问题见 A2,死代码见 A1)。

## D 组:JS web stubs

| ID | 级别 | 文件 | 问题 | 建议修法 | 状态 |
|----|------|------|------|----------|------|
| D1 | 🟡 cleanup | `src/*.web.tsx` + vite/react-native-web | web stub 覆盖不全(6/12 组件)、`MapView.web` handle 不全;且无 web 需求 | **整层移除**:删 6 个 `*.web.tsx` + `example/{index.html,vite.config.mjs}` + 两个 package.json 的 web 脚本/依赖 | ✅ |

## E 组:Android 核心(MapView.kt)

> 整体质量高:lifecycle 完整、事件 coalesce 合理、坐标转 dp、marker 事件路由、InfoWindowAdapter 接 Callout。无泄漏/崩溃级问题。

| ID | 级别 | 文件 | 问题 | 建议修法 | 状态 |
|----|------|------|------|----------|------|
| E1 | ⚪ minor(correctness) | `android/.../MapView.kt` | `isGesture` 在 ACTION_DOWN 置真,仅 `onCameraChangeFinish` 复位;纯点击后会粘住 → 下次(程序化)相机变化误报 `isGesture=true` | ACTION_UP/CANCEL 复位,或只在 MOVE 置真 | ✅ DOWN 清零 + MOVE 置真 |
| E2 | ⚪ minor(behavior) | `android/.../MapView.kt` | `setOnMarkerClickListener` 返回 `false` → AMap 默认把地图居中到 marker,RNM 不会 | 返回 `true` 并按需手动 `showInfoWindow()` | ✅ consume + 有内容才 showInfoWindow |
| E9 | 🟡 cleanup(perf/ANR) | `android/.../MapView.kt` | `takeSnapshotResult` 在主线程回调里同步 `Bitmap.compress` + 写盘,大图可能卡顿/ANR | 压缩+写盘移到后台线程,完成再 `dispatchCommandResult` | ✅ deliverSnapshot 移入后台 Thread |
| E4 | ⚪ minor(parity) | `android/.../MapView.kt` | `fitToCoordinates` 的 edgePadding 取四边最大值(单一 padding) | 改用 `CameraUpdateFactory.newLatLngBoundsRect(bounds,l,r,t,b)` 逐边 | ✅ newLatLngBoundsRect 逐边 padding |
| E6 | ⚪ minor(semantic) | `android/.../MapView.kt` | `showsPointsOfInterest` → `showMapText` 会隐藏所有文字标注,非仅 POI | 文档说明;AMap 无 POI-only 开关 | ✅ types.ts JSDoc 标注 best-effort(全部标注) |
| E8 | ⚪ info | `android/.../MapView.kt` | `addFeature` 未知子 view `else->return` 不计入 features,理论上 getChildCount 可能不一致 | 实际只 mount 已知类型,低风险;可加断言 | ✅ BuildConfig.DEBUG 告警未知子 view |

## F–G 组:Android marker/覆盖物/瓦片

| ID | 级别 | 文件 | 问题 | 建议修法 | 状态 |
|----|------|------|------|----------|------|
| F3 | 🟡 cleanup(parity/correctness) | `MapView.kt` + `PolylineView.kt` / `PolygonView.kt` | Polyline/Polygon 的 `emitPress()` **从未被调用**——configureMap 无 `setOnPolylineClickListener`/polygon 点击监听,`onPress`/`tappable` 在 Android 上不触发(M5_DESIGN 却声称已支持,文档与实现不符;emitPress 为死方法) | 给 PolylineView 的 polyline 设 `object=this` + configureMap 加 `setOnPolylineClickListener` 路由;Polygon 多数 AMap 版本无点击回调→文档化 best-effort | ✅ Polyline:接 `setOnPolylineClickListener` 按 tappable 路由 emitPress(编译确认 AMap 有此 API);Polygon:AMap Android 无点击 API,文档化不支持 |
| F4 | 🟡 cleanup(跨端不一致) | `PolygonView.kt` / `PolygonManager.kt` | **`holes` 在 iOS 已实现(`interiorPolygons:`)、Android 静默忽略** → 同一 API 双端行为不一致(更值得修);M5_DESIGN 声称支持 | 新版 AMap `PolygonOptions.addHoles()` 实现 Android holes,对齐 iOS | ✅ PolygonHoleOptions.addHoles,双端一致 |
| F1 | ⚪ minor(perf) | `MarkerView.kt` | 自定义内容每次 `Bitmap.createBitmap` 不 recycle 旧 `customBitmap`,`tracksViewChanges` 频繁重绘 GC 压力 | 替换前 recycle 旧位图;detach 时也 recycle | ✅ 替换/还原/detach 全部 recycle(含 iconBitmap) |
| F2 | ⚪ minor(robustness) | `MarkerView.kt` / `OverlayView.kt` / `UrlTileView.kt` / `HeatmapView.kt` | 网络图/瓦片解码用 `URL.openStream()` 无超时,坏网络挂住线程;每张图新建 `Thread`(无线程池) | 设连接/读超时;考虑共享线程池 | ✅ MapsImageLoader 共享守护线程池 + 15s 连接/读超时(Marker/Overlay) |

## H 组:iOS 核心(RNMapsMapView.mm)

> 质量高,和 Android 对称;`prepareForRecycle`/`dealloc` 处理到位;`_isGesture` 比 Android 更干净(无粘住),点 marker 不重定位(无 Android E2 问题)。

| ID | 级别 | 文件 | 问题 | 建议修法 | 状态 |
|----|------|------|------|----------|------|
| H-arch | 🔵 architecture(风险) | 全部 `ios/*.mm` | iOS 从未真机编译:命令选择器需匹配 codegen `RCTRNMaps*ViewProtocol`;Overlay/Heatmap/瓦片/渐变 Polyline 依赖的 AMap iOS 符号全靠推导 | 首次 `pod install`+编译,按报错逐个修(见 VERIFICATION_CHECKLIST iOS 段) | ✅ iOS 首次编译+真机/模拟器验证全通过(2026-06-06)。逐项发现见下方「iOS bring-up」 |
| H1 | ⚪ minor | `ios/RNMapsMapView.mm` | 显示/手势开关每次 updateProps 无条件重设(无 old≠new 守卫),`showsUserLocation` 反复设可能反复触发定位 | 加 old≠new guard,像 mapType/zoom 那样 | ✅ 守卫 `showsUserLocation`(有副作用);其余幂等开关不守卫以免首帧默认错配。**未真机编译验证** |
| H2 | ⚪ info | `ios/RNMapsMapView.mm` | `showsLabels`←`showsPointsOfInterest` 控制所有标注非仅 POI(同 Android E6) | 文档化 best-effort | ✅ 随 E6 在 types.ts JSDoc 标注 |

## I–J 组:iOS marker/覆盖物/瓦片

> 已走读:整体干净,质量与 Android 相当。`RNMapsMarker.mm`(CADisplayLink 正确 invalidate、无保留环;图片 weak+stale;`UIGraphicsImageRenderer` 栅格化)、`RNMapsPolygon.mm`(**holes 已实现**)、`RNMapsCallout.mm`/`RNMapsCircle.mm` 均无独立问题。iOS 图片走 `NSURLSession`(默认 60s 超时),不像 Android F2 裸流无超时。
>
> 唯一登记项已并入 **F4**(holes 跨端不一致)与 **H-arch**(iOS 整体未真机编译)。本组无新增独立 finding。

## K 组:example + 配置(podspec / gradle)

| ID | 级别 | 文件 | 问题 | 建议修法 | 状态 |
|----|------|------|------|----------|------|
| K1 | ⚪ minor(repro) | `android/build.gradle` | 库默认 AMap 依赖 `latest.integration`(动态版本)→ 消费者构建不可复现 + metadata 拉取脆弱(与 example 早期同款问题) | 文档强调 host 用 `ext.amapSdkVersion` 钉版本,或库默认给一个稳定版本 | ✅ 库默认钉 `11.2.000_loc11.2.000_sea9.8.0`,host 仍可 `ext.amapSdkVersion` 覆盖 |
| K2 | ⚪ minor(repro) | `CnMaps.podspec` | `s.dependency "AMap3DMap"` 未钉版本 → iOS 不可复现 | 钉一个已验证的 AMap3DMap 版本 | ✅ 钉 `~> 11.1.200`(Podfile.lock 已解析验证) |
| K3 | ⚪ info | `CnMaps.podspec` + `clean` 脚本 | `source_files = ios/**` 会递归匹配本地 `ios/build/generated`(codegen 产物),可能与 RNMapsSpecs pod 重复编译;`clean` 脚本未清库自身 `ios/build` | 已 gitignore+不发布,风险低;`clean` 加上 `ios/build`,或 podspec 排除 `ios/build` | ✅ podspec `exclude_files = ios/build/**` + `clean` 脚本加 `ios/build` |

---

## V 组:真机验证发现(走读后补)

| ID | 级别 | 文件 | 问题 | 修法 | 状态 |
|----|------|------|------|------|------|
| V1 | 🔴 correctness | `android/.../MarkerView.kt` + `OverlayView.kt` | **image marker / custom-content marker 显示默认红钉,且 `<Overlay>` 图片完全不显示**。根因:MarkerView 是被地图拦截的离屏 View(从不 attach 到 window),`this.post{}`(图片加载回调 + 自定义内容栅格化调度)在未 attach 的 View 上**永不执行** | 改用主线程 `Handler` 调度;栅格化用 Fabric 经 `onLayout` 给的 width/height(**不可** Android `measure()` —— RN catalyst view 会抛 "must have explicit width and height") | ✅ 真机验证渲染正常 |

| V2 | 🔴 correctness | `HeatmapView.kt` + host `gradle.properties` | `<Heatmap>` 在真机上**完全不显示**:AMap `HeatmapTileProvider.build()` 抛 `ClassNotFoundException: android.support.v4.util.LongSparseArray`(AMap 热力图仍依赖旧 Support 库,AndroidX 项目无此类) | host app 开 `android.enableJetifier=true`(example 已加;README 已注明)。代码层无法绕过——AMap 该组件内部硬引用旧类 | ✅ example 开 Jetifier + README 注明(真机确认热力图显示) |

---

## iOS bring-up findings(首次真机/模拟器验证,2026-06-06)

> iOS 端首次实际编译+运行才暴露的问题。多数是**库级真 bug**——任何使用本库的 iOS app 都会中招,走读和编译都发现不了。全部已修并真机/模拟器验证。

| ID | 级别 | 文件 | 问题 | 修法 | 状态 |
|----|------|------|------|------|------|
| iOS-1 | 🔴 correctness | `ios/RNMapsPolyline.mm` | 用了不存在的 `MAMultiColoredPolyline` overlay 类 | `MAMultiPolyline`+`drawStyleIndexes`,renderer `initWithMultiPolyline:`,ivar 放宽 `MAShape*` | ✅ |
| iOS-2 | 🔴 correctness | `ios/RNMapsPolygon.mm` | holes 用 MapKit 的 `polygonWithCoordinates:count:interiorPolygons:` | 改 AMap `MAPolygon.hollowShapes` 属性 | ✅ |
| iOS-3 | 🔴 correctness | `ios/RNMapsHeatmap.mm` | `MAHeatMapNode.radius` / `MAHeatMapGradient ...colorMapSize:` 不存在 | radius 设到 overlay;gradient 去掉 colorMapSize 参数 | ✅ |
| iOS-4 | 🔴 correctness | `ios/RNMapsMapView.mm` | snapshot `takeSnapshotInRect:withCallback:` 名错;camera helper 写死结构体收不下 `initialCamera` | `withCompletionBlock:`;`RNMapsCameraIsValid`/`RNMapsApplyCamera` 模板化 | ✅ |
| iOS-5 | 🔴 correctness(崩溃) | 7 个 `*NativeComponent.ts` | `onPress` 声明 `DirectEventHandler`,与 iOS 核心 bubbling `topPress` 冲突 → redbox「Event cannot be both direct and bubbling」 | 全改 `BubblingEventHandler`(iOS 核心有 topPress、Android 没有) | ✅ |
| iOS-6 | 🔴 correctness(崩溃) | `ios/RNMaps{Circle,Marker,Polygon,Polyline}.mm` | `updateProps` 解引用 `oldProps` 参数,**首次挂载该参数为 nullptr** → EXC_BAD_ACCESS | 改用 `_props`(上次已应用的 props,永不为空) | ✅ |
| iOS-7 | 🔴 correctness | `ios/RNMapsMapView.mm` | `initialRegion` 在布局前 `setRegion` 被 AMap 忽略 → 停在默认北京全国视图 | 捕获为 pending,`mapInitComplete`(地图就绪)+ `layoutSubviews`(有尺寸)后再应用 | ✅ |
| iOS-8 | 🔴 correctness(崩溃+不渲染) | `package.json` codegenConfig | UrlTile/LocalTile/Overlay/Heatmap **未注册** iOS Fabric 组件 → 通用占位视图 → 不渲染 + 卸载越界崩溃 | 4 个组件补进 `codegenConfig.ios.components` | ✅ |
| iOS-9 | 🔵 build | `CnMaps.podspec` 消费侧 + Podfile | AMap framework **无 arm64-模拟器切片**(只有 arm64-真机 + x86_64-sim)→ Apple Silicon 模拟器 App=x86_64/pod=arm64 链接失败 | host Podfile `post_install` 给所有 pod 加 `EXCLUDED_ARCHS[sim]=arm64`(已写进 README);真机 arm64 不受影响 | ✅ |
| iOS-10 | 🔵 build(env) | `example/ios/.xcode.env.local` | 真机 Debug 打 JS bundle 用旧 Node v22.2.0,`metro.config` 的 ESM `react-native-monorepo-config` 需 Node ≥22.12 → `ERR_REQUIRE_ESM` | host 把 `NODE_BINARY` 指向 ≥22.12 的 node(本地 env) | ✅ |
| iOS-priv | 🟡 feature | `ios/RNMapsModule.{h,mm}` | iOS 无 `setPrivacyConsent` 实现(只 Android 有)→ 地图不初始化 | 新增 TurboModule:`MAMapView +updatePrivacyShow:privacyInfo:`/`+updatePrivacyAgree:` | ✅ |

---

## 走读完成度

A ✅ · B ✅ · C ✅ · D ✅(已修) · E ✅ · F/G ✅ · H ✅ · I/J ✅ · K ✅ —— **全工程逐组走读完成。**
