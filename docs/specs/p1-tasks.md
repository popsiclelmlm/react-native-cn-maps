# Tasks: P1 实现任务拆分 —— Adapter 重构 + Monorepo 拆分

> 状态：**Phase 3 / Tasks**
> 上游：[`p1-plan.md`](./p1-plan.md)（决策 D1–D4 已锁定） · [`p1-adapter-refactor-and-monorepo.spec.md`](./p1-adapter-refactor-and-monorepo.spec.md)
> 约定：每个任务 **≤5 个文件**；带「范围 / 验收 / 验证」三段；标注依赖。
> 轨道：`[i]` iOS、`[a]` Android、`[x]` 跨端/共享。**i 与 a 可并行**；同轨道内按编号顺序。

---

## 依赖图（先看这张）

```
M1（单包·原地重构）
  i-01 协议 ─┐                       a-01 协议 ─┐
  i-02 模型 ─┼─► i-03 Host接Adapter   a-02 模型 ─┼─► a-03 Host接Adapter
            │      (地图级)                     │      (地图级)
            └──────────┴─► i-04 Marker(范式)    └──────────┴─► a-04 Marker(范式)
                              │                                   │
              i-05..i-10 其余覆盖物(可并行)        a-05..a-10 其余覆盖物(可并行)
                              │                                   │
                          i-11 隐私fan-out                    a-11 隐私fan-out
                              └──────────────┬──────────────────┘
                                       ✅ 检查点 A（D2：我跑双端矩阵）
                                              │
M2（monorepo·物理拆包）                        ▼
  x-01 仓库骨架 ─► x-02 core 落位 ─► x-03 amap包(iOS) ┐
                                   x-04 amap包(Android)┼─► x-05 example接线 ─► ✅ 检查点 B
                                   x-06 注册入口(i+a) ─┘
```

> 注:iOS 比 Android 多一个共享任务 **i-04b 覆盖物协议无关化**——`RNMapsOverlay.h` 的 `RNMapsOverlayView` 协议 `#import <MAMapKit/...>` 且返回 `id<MAOverlay>`/`MAOverlayRenderer`,必须先去 SDK 类型。Android 子组件直调 `aMap.addX`、不存在「协议返回 SDK 类型」问题,故无对应任务。
> **marker 走 annotation 机制,与覆盖物协议无关**——i-04(annotation 范式) 与 i-04b(overlay 协议) 是两条不同范式,i-05..i-10 复用的是 i-04b。

---

# 里程碑 M1 —— 原地逻辑重构（单包，行为不变）

## i-01 [i] iOS 协议与回调脚手架
- **范围**：新建 `ios/Adapter/CNMapAdapter.h`（地图/覆盖物/命令/快照/隐私抽象协议）、`CNMapAdapterDelegate.h`（Adapter→Host 事件回路，签名带 `childId`）、`CNMapAdapterRegistry.h`、`CNMapAdapterRegistry.m`（provider 名→Adapter 类；隐私 fan-out 入口）。空骨架，可编译。
- **验收**：协议方法覆盖 plan §2 五类职责；Registry 提供 `registerAdapterClass:` 与 `defaultAdapter`；无任何 `MAMap/AMap` 引用。
- **验证**：`yarn example ios` 构建通过（脚手架未接线，零行为变化）。
- **依赖**：无。

## i-02 [i] iOS 统一模型与覆盖物句柄
- **范围**：新建 `ios/Adapter/CNMapModels.h`（`CNMarkerModel`/`CNPolylineModel`/`CNPolygonModel`/`CNCircleModel`/`CNHeatmapModel`/`CNTileModel`/`CNGroundOverlayModel` 等值对象，单头文件汇总）、`CNOverlayHandle.h`、`CNOverlayHandle.m`（Adapter 返回、Host 持有，供 update/remove）。
- **验收**：模型字段 provider 无关（经纬度/样式用基础类型，不出现 `CLLocationCoordinate2D` 之外的 AMap 类型）；句柄不透明持有 SDK 对象引用。
- **验证**：构建通过。
- **依赖**：无（与 i-01 可并行）。

## i-03 [i] iOS Host 接 Adapter（地图级）
- **范围**：`ios/CNAMapAdapter.h` + `ios/CNAMapAdapter.mm`（实现协议的地图级部分：创建 MAMapView、region/camera、投影、snapshot、地图级命令与 delegate）、`ios/RNMapsMapView.mm`（改为持 `id<CNMapAdapter>`，挂载 `adapter.mapView`，转发地图级调用）。**子组件暂不动**。
- **验收**：地图显示、移动、`onRegionChange`、地图级命令均经由 Adapter；`RNMapsMapView.mm` 内不再直接出现 `MAMapView` 创建代码。
- **验证**：`yarn example ios` → 地图可显示/缩放/平移；snapshot 命令可用。
- **依赖**：i-01、i-02。

## i-04 [i] iOS Marker 迁移（annotation 哑子组件 + 事件回路范式）★关键
> marker 用 **annotation** 机制（`addAnnotation:` + `annotation.marker` 弱引用），不走 `RNMapsOverlayView` 协议——本任务确立的是 annotation 范式。
- **范围**：`ios/RNMapsMarker.mm`（哑化：持 props、暴露 `markerModel`、持 Fabric event emitter，删除 `addAnnotation:`/`annotation.marker` 弱引用）、`ios/RNMapsCallout.mm`（callout 随 marker 哑化）、`ios/CNAMapAdapter.mm`（`addMarker:`/`removeAnnotation:` + SDK annotation↔childId 映射 + 点击/拖拽回调经 delegate 带 childId 上报）、`ios/RNMapsMapView.mm`（挂卸注入 childId、调 adapter、按 childId 路由事件回子组件 emit）。= 4 文件。
- **验收**：marker 显示、点击/拖拽/Callout 事件与重构前一致；事件经 childId 注册表回路（plan §4.1），无 AMap 对象弱引用。
- **验证**：example 验 marker 全部交互（点击、拖拽、callout 点击）。
- **依赖**：i-03。**确立 annotation 范式。**

## i-04b [i] iOS 覆盖物协议无关化（共享，覆盖物组前置）★关键
- **范围**：`ios/RNMapsOverlay.h`（重定义 `RNMapsOverlayView`：删 `#import <MAMapKit/...>`，`overlay`/`overlayRenderer` 改为暴露 `CNOverlayModel`；保留 provider 无关的 `RNMapsParseDashPattern`/`RNMapsCoordinatesEqual` 内联辅助）、`ios/CNAMapAdapter.mm`（新增 `mapView:rendererForOverlay:` 工厂 + `addOverlay:`/`removeOverlay:` 返回 `CNOverlayHandle`）。= 2 文件。
- **验收**：`RNMapsOverlay.h` 内无 `MAMapKit`/`MAOverlay` 引用；renderer 创建集中在 Adapter。
- **验证**：构建通过（协议接线由 i-05 起逐类落地，本任务不改运行行为）。
- **依赖**：i-03。**确立 overlay 范式，i-05..i-10 复用。**

## i-05..i-10 [i] iOS 其余覆盖物迁移（按 i-04b 范式，彼此可并行）
> 每个任务范围固定为该类型的：子组件 `.mm` + `CNAMapAdapter.mm`(addX/removeOverlay/renderer) + `RNMapsMapView.mm`(挂卸路由)，≤5 文件。renderer 创建集中进 Adapter 的 `mapView:rendererForOverlay:`，保持「形态改变=remove+add 重建」语义。

| 任务 | 类型 | 子组件文件 | 特例 |
|---|---|---|---|
| i-05 | Polyline | `RNMapsPolyline.mm` | — |
| i-06 | Polygon | `RNMapsPolygon.mm` | holes 孔洞 |
| i-07 | Circle | `RNMapsCircle.mm` | — |
| i-08 | Heatmap | `RNMapsHeatmap.mm` | 权重点 |
| i-09 | Tiles | `RNMapsUrlTile.mm` / `RNMapsLocalTile.mm` | 两类合一任务 |
| i-10 | GroundOverlay | `RNMapsImageOverlay.mm` | 图片锚定 |

- **验收（每项）**：该覆盖物显示与交互行为不变；子组件内 AMap 引用=0；renderer 由 Adapter 创建。
- **验证（每项）**：example 验该类型增删改与（如有）事件。
- **依赖**：i-04b（覆盖物协议无关化）。i-04（marker/annotation）与本组并行、互不依赖。

## i-11 [i] iOS 隐私 fan-out
- **范围**：`ios/CNAMapAdapter.mm`（`setPrivacyConsent` 的 AMap 实现移入）、`ios/RNMapsModule.mm`（隐私 TurboModule 改为向 `CNMapAdapterRegistry` 已注册适配器广播，保持调用时序，不复现 555570 时序问题）。
- **验收**：隐私同意时序与重构前一致；TurboModule 内无 AMap 引用。
- **验证**：example 冷启首屏地图正常加载（隐私链路通）。
- **依赖**：i-01、i-03。

---

（Android 轨道与 iOS 镜像，可并行）

## a-01 [a] Android 协议与回调脚手架
- **范围**：`android/.../adapter/CnMapAdapter.kt`（抽象接口）、`CnMapAdapterDelegate.kt`（回调带 `childId`）、`CnMapAdapterRegistry.kt`（provider→factory；隐私 fan-out）。
- **验收 / 验证 / 依赖**：同 i-01（`yarn example android` 构建通过）。

## a-02 [a] Android 统一模型与覆盖物句柄
- **范围**：`android/.../adapter/CnMapModels.kt`（各 `Cn*Model` data class）、`OverlayHandle.kt`。
- **验收 / 验证 / 依赖**：同 i-02。

## a-03 [a] Android Host 接 Adapter（地图级）
- **范围**：`android/.../amap/AMapAdapter.kt`（实现协议地图级部分）、`android/.../MapView.kt` + `MapViewManager.kt`（改持 `CnMapAdapter`，挂载 `adapter.view`，转发）。
- **验收**：地图显示/移动/区域事件/地图级命令经 Adapter；`MapView.kt` 不再直接持 `AMap` 创建逻辑。
- **验证**：`yarn example android` 地图可显示/操作。
- **依赖**：a-01、a-02。

## a-04 [a] Android Marker 迁移（哑子组件 + 事件回路范式）★关键
> Android 无「协议返回 SDK 类型」问题（子组件直调 `aMap.addMarker`），故**无 i-04b 对应任务**；此范式同时供覆盖物组(a-05..a-10)复用。
- **范围**：`android/.../MarkerView.kt`（哑化：删 `aMap.addMarker`/`marker.object=this`，暴露 `model()` + 持 Fabric emitter）、`CalloutView.kt`（callout 随 marker 哑化）、`AMapAdapter.kt`（`addMarker(model)` + SDK↔childId 映射 + 点击/拖拽 listener 带 childId 上报）、`MapView.kt`（挂卸注入 childId、按 childId 路由回 emit）。= 4 文件（`MarkerManager.kt` prop 路由通常不变，如需动计入）。
- **验收 / 验证**：同 i-04（Android 侧）。
- **依赖**：a-03。**确立范式供 a-05..a-10 复用。**

## a-05..a-10 [a] Android 其余覆盖物迁移（按 a-04 范式，可并行）
| 任务 | 类型 | 子组件文件 | 特例 |
|---|---|---|---|
| a-05 | Polyline | `PolylineView.kt` | — |
| a-06 | Polygon | `PolygonView.kt` | holes |
| a-07 | Circle | `CircleView.kt` | — |
| a-08 | Heatmap | `HeatmapView.kt` | 权重点 |
| a-09 | Tiles | `UrlTileView.kt` / `LocalTileView.kt` | 合一任务 |
| a-10 | GroundOverlay | `OverlayView.kt` | 图片锚定 |
> 每类另有伴生 `*Manager.kt`(Fabric ViewManager)；哑化后其 prop 路由通常不变，如需改动计入该任务（View+Manager+`AMapAdapter.kt`+`MapView.kt` ≤5）。
- **验收 / 验证（每项）**：该覆盖物行为不变；子组件内 `com.amap` 引用=0。
- **依赖**：a-04。

## a-11 [a] Android 隐私 fan-out
- **范围**：`AMapAdapter.kt`（`setPrivacyConsent` 实现移入）、`android/.../MapsPrivacy.kt`（隐私 module 改为向 `CnMapAdapterRegistry` 广播）。
- **验收 / 验证 / 依赖**：同 i-11。

---

## ✅ 检查点 A（M1 完成，仍单包）— 由我执行（D2）
```sh
yarn test && yarn typecheck && yarn lint
yarn example ios && yarn example android   # run 技能驱动模拟器
grep -rEn 'AMap|MAMap|com\.amap' ios android \
  --include='*.mm' --include='*.m' --include='*.h' --include='*.kt' | grep -v Adapter
# expect: 仅 *Adapter 文件命中（含 RNMapsOverlay.h 已去 MAMapKit）
```
- [ ] example 双端跑通 spec §Testing 的 9 类回归矩阵，行为与重构前一致
- [ ] AMap 引用仅存在于 `*Adapter` 文件，Host 与子组件文件内为 0
- [ ] jest / typecheck / lint 全绿

---

# 里程碑 M2 —— 物理拆包（转 monorepo）

> 依赖检查点 A 通过。x-03/x-04/x-06 可并行。

## x-01 [x] 仓库骨架与 workspace 根
- **范围**：根 `package.json`（转私有 workspace 根：`workspaces:["packages/*","example"]`，**删除 `codegenConfig`**，构建脚本下沉）、新增 `turbo.json`（编排 core 构建）、新增 `packages/core/package.json`、`packages/amap/package.json` 骨架。
- **验收**：`yarn install` 解析出 core/amap/example 三 workspace；根不再含 codegenConfig。
- **验证**：`yarn install` 成功；`yarn workspaces info` 列出三包。
- **依赖**：检查点 A。

## x-02 [x] core 源码落位
- **范围**：`src/` → `packages/core/src/`；core 的 `ios/`、`android/` → `packages/core/{ios,android}/`；`packages/core/package.json` 接入 `codegenConfig`（`jsSrcsDir:"src"` 相对 core 包根，含 10 个 Fabric 组件 + TurboModule）；core podspec/gradle 暂留 AMap 依赖（x-03/x-04 再删）。
- **验收**：`packages/core/src/index.tsx` 导出与重构前一致；codegen 定位到 `packages/core/src`。
- **验证**：`yarn workspace react-native-cn-maps prepare`（或等价 codegen）生成 RNMapsSpecs 到 core 内，路径正确。
- **依赖**：x-01。

## x-03 [x][i] amap 包成形（iOS）
- **范围**：`AMapAdapter`(CNAMapAdapter.h/.mm) → `packages/amap/ios/`；新建 `packages/amap/CnMapsAMap.podspec`（携 `AMap3DMap ~> 11.1.200`，`source` 同 repo 同 tag — D3，`dependency` 指向 core 的 pod）；`packages/core` 的 podspec **删除** `AMap3DMap`。
- **验收**：core podspec 内无 `AMap3DMap`；amap podspec 携高德依赖且 depend on core。
- **验证**：example `pod install` 同时拉到 core + amap 两 pod。
- **依赖**：x-02。

## x-04 [x][a] amap 包成形（Android）
- **范围**：`AMapAdapter.kt` → `packages/amap/android/`；新建 `packages/amap/android/build.gradle`（`com.amap.api` + `ext.amapSdkVersion=11.2.000...`，`namespace/javaPackageName = com.cnmaps.amap` — D4）；`packages/amap/android/src/main/AndroidManifest.xml`（**不**重复声明 example 已有权限）；`packages/core` 的 `build.gradle` **删除** `com.amap.api`。
- **验收**：core gradle 内无 `com.amap.api`；amap 命名空间为 `com.cnmaps.amap`，与 core codegen 命名空间无冲突。
- **验证**：`yarn example android` 配置阶段 gradle sync 通过。
- **依赖**：x-02。

## x-06 [x] amap 自注册入口（iOS + Android）
- **范围**：iOS `packages/amap/ios/CNAMapAdapter.mm` 加 `+load` 调 `[CNMapAdapterRegistry registerAdapterClass:self]`；Android `packages/amap/android/.../AMapPackage.kt`（仅注册副作用的 `ReactPackage`）+ 在加载路径 `CnMapAdapterRegistry.register(AMapAdapterFactory)`；core 兜底：无已注册 Adapter 时 `__DEV__` 抛明确错误（"未安装 react-native-cn-maps-amap"）。
- **验收**：autolink amap 后宿主零代码即注册；core 缺适配器时报清晰错误而非白屏。
- **验证**：临时移除 amap 依赖跑 example，确认报出兜底错误；恢复后地图正常。
- **依赖**：x-03、x-04。

## x-05 [x] example 接两个包 + 接线修复
- **范围**：`example/react-native.config.js`（两个 dependency：`../../packages/core`、`../../packages/amap`）、`example/ios/Podfile`（post_install arm64 排除遍历**所有** pod target，覆盖 amap 引入的 `AMap3DMap`/`AMapFoundation`）、`example/android/.../gradle.properties`（保留 `enableJetifier=true`）、`example/package.json`（依赖两包）。
- **验收**：example 仅装 `react-native-cn-maps` + `react-native-cn-maps-amap` 即双端跑通；Apple Silicon 模拟器链接成功；merged manifest 权限无冲突。
- **验证**：`pod install` + `yarn example ios`（含 Apple Silicon 模拟器）、`yarn example android`。
- **依赖**：x-03、x-04、x-06。

---

## ✅ 检查点 B（M2 完成，monorepo）— 由我执行（D2）
```sh
grep -rE 'AMap|MAMap|com\.amap' packages/core ; echo "expect: no matches"
yarn test && yarn typecheck && yarn lint
yarn example ios && yarn example android
```
- [ ] `packages/core` 内高德引用 grep = 0（spec 验收 #2/#3）
- [ ] core podspec 无 `AMap3DMap`、core gradle 无 `com.amap.api`
- [ ] example 仅装 core + amap 两包即双端跑通全 9 类矩阵
- [ ] JS 公开 API / `index.tsx` 导出与重构前一致

---

## 风险锚点（对应 plan §5）
- i-04 / a-04 是 **R1**（事件回路）首次落地点，务必先打通再推广 i-05+/a-05+。
- i-05..i-10 的 renderer 迁移对应 **R2**。
- x-05 对应 **R3**（arm64）+ **R5**（manifest/Jetifier）。
- x-01/x-02 对应 **R4**（codegen 路径）。
