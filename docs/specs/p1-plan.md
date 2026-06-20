# Plan: P1 实现计划 —— Adapter 重构 + Monorepo 拆分

> 状态：**待评审（Phase 2 / Plan）** —— 通过后再进 Tasks
> 对应 spec：[`p1-adapter-refactor-and-monorepo.spec.md`](./p1-adapter-refactor-and-monorepo.spec.md)
> 机制依据：本计划基于对原生挂载机制与打包接线的实地摸底（见 §1）

---

## 0. 总体策略（先读这段）

把 P1 拆成**两个各自可独立验证的里程碑**，刻意把「逻辑重构风险」与「构建/打包风险」分开：

```
里程碑 M1：原地逻辑重构（仍是单包）
  引入 Adapter 协议 + Registry + Host 容器，子组件改哑数据，
  高德代码收进 AMapAdapter（但仍在同一包内）。
  验收：jest 全绿 + example 双端功能不回归；AMap 引用只剩在 *Adapter 文件里。
            │
            ▼
里程碑 M2：物理拆包（转 monorepo）
  把 core 与 amap 拆成两包，SDK 依赖搬家，autolink 两个原生包。
  验收：同上 + packages/core 内 grep AMap = 0（spec 验收 #2/#3）。
```

**为什么这样分**：若直接「边拆包边重构」，一旦 example 起不来，无法判断是 Adapter 抽象错了还是 autolink/codegen 接线错了。分两段后，M1 出问题 = 逻辑层；M2 出问题 = 构建层。

---

## 1. 机制摸底结论（塑造本计划的关键事实）

**原生挂载（两端一致、对重构有利的部分）**
- 子组件**不**向上找父；由父容器在 `mountChildComponentView:`(iOS) / `addFeature`(Android) 中主动调子的 `addToMap:` / `attachTo(aMap)`。
- 覆盖物已走统一协议：iOS `RNMapsOverlayView`(`overlay`/`addToMap:`/`removeFromMap`/`overlayRenderer`)；Android `attachTo/detach`。

**必须改造的耦合点**
- 子组件直接调 AMap：iOS `[map addAnnotation:]`(`RNMapsMarker.mm:225`)、Android `aMap.addMarker(options)`(`MarkerView.kt:183`)。→ 与验收 #3 冲突，必须移走。
- 事件回传依赖 AMap 对象上的弱引用：iOS `annotation.marker`(`RNMapsMarker.mm:99`)、Android `marker.object = this`(`MarkerView.kt:184`)，父 delegate/listener 借此回路到子。
- iOS 覆盖物协议返回 **MAOverlay/MAOverlayRenderer**（AMap 类型）—— 协议本身需 provider 无关化。

**留在 Host 的 provider-agnostic 职责**
- Fabric/ViewGroup 生命周期、子组件挂卸路由、事件/命令统一入口、子组件集合维护、初始 viewport 延迟应用、手势(iOS gesture recognizer / Android GestureDetector)。

**打包接线（实地确认）**
- example **不**靠 node_modules symlink，而是 `example/react-native.config.js:10-19` 手动 `root:".."` + `use_native_modules!`(iOS) / `autolinkLibrariesFromCommand()`(Android)。
- AMap 版本：iOS `AMap3DMap ~> 11.1.200`(`CnMaps.podspec:26`)、Android `11.2.000_loc...`(`android/build.gradle:10,71`)。
- `android.enableJetifier=true` 必需(`example/.../gradle.properties:27`)；iOS post_install 排除 arm64 模拟器 slice(`example/ios/Podfile:40-44`)。
- `codegenConfig` 现于根 `package.json:114-155`，`jsSrcsDir: src`。

---

## 2. 组件与依赖

**新增（core 侧，provider 无关）**
| 组件 | iOS | Android | 职责 |
|---|---|---|---|
| 适配器协议 | `CNMapAdapter.h` | `adapter/CnMapAdapter.kt` | 定义地图/覆盖物/命令/事件/隐私的抽象接口 |
| 统一模型 | `CN*Model`(Marker/Polyline/…) | `Cn*Model` | 子组件 → Adapter 的 provider 无关数据 |
| 覆盖物句柄 | `CNOverlayHandle` | `OverlayHandle` | Adapter 返回、Host 持有，用于 update/remove |
| 注册表 | `CNMapAdapterRegistry` | `CnMapAdapterRegistry` | provider 名 → Adapter；隐私 fan-out |
| Adapter 回调 | `CNMapAdapterDelegate` | `CnMapAdapterDelegate` | Adapter → Host 的事件回路（带 childId） |

**改造（core 侧）**
- Host 容器：`RNMapsMapView.mm` / `MapView.kt`+`MapViewManager.kt` —— 从「直接持 MAMapView/AMap」改为「持 `id<CNMapAdapter>`，挂载 `adapter.mapView`，转发一切」。
- 哑子组件：所有 `RNMaps*`(iOS) / `*View.kt`(Android) 覆盖物 —— 退化为「持 props + 暴露统一模型 + 持 Fabric event emitter」，删除一切 AMap 调用。

**新增（amap 包，M2 才物理分离）**
- `CNAMapAdapter` / `AMapAdapter`：实现协议，承载现有所有高德逻辑（创建 MAMapView、增删覆盖物、投影、snapshot、命令、delegate/listener、隐私）。
- amap 注册入口：iOS `+load` 自注册；Android 一个仅做注册副作用的 `ReactPackage`。

**依赖方向**：`amap` → `core`（amap 依赖 core 的协议）；`core` 不依赖任何 provider 包。

---

## 3. 实现顺序

### 里程碑 M1（原地逻辑重构，单包）

> iOS 与 Android 是两条**可并行**的工作流；各自内部 S1→S2→S3 顺序。

- **M1-S1 协议与脚手架**（先行，无行为变化）
  定义协议 / 模型 / 句柄 / Registry / Delegate 的类型骨架，空实现可编译。

- **M1-S2 Host 接 Adapter（地图级）**
  Host 改为创建并持有 `AMapAdapter`，把**地图创建、region/camera、投影、snapshot、命令、地图级事件**从 Host 内联代码搬进 Adapter。子组件**暂不动**（仍直接调 AMap），先确保地图级链路通。
  ✅ 中间验证：地图能显示、能移动、命令可用。

- **M1-S3 哑子组件 + 覆盖物入 Adapter**（最大、最难一步）
  逐覆盖物类型迁移：子组件改为只暴露统一模型；Host 在挂卸时 `adapter.addX(model)`/`removeOverlay(handle)`；**事件回传改 childId 注册表**（见 §4.1）。iOS 覆盖物协议 `RNMapsOverlayView` 改为返回模型而非 MAOverlay，renderer 创建移入 Adapter。
  顺序建议：Marker（含 Callout 特例）→ Polyline → Polygon(holes 特例) → Circle → Heatmap → UrlTile/LocalTile → Overlay(ground)。每类迁完即在 example 验该类功能。

- **M1-S4 隐私 fan-out**
  `setPrivacyConsent` 的 AMap 实现移入 Adapter；core 的 TurboModule 改为向 Registry 已注册适配器广播。保证时序不变（不复现 555570）。

✅ **检查点 A**（见 §6）。

### 里程碑 M2（物理拆包，转 monorepo）

> 依赖 M1 完成；iOS 与 Android 接线**可并行**。

- **M2-S1 仓库骨架**
  建 `packages/core`、`packages/amap`；根 `package.json` 转私有 workspace 根（`workspaces:["packages/*","example"]`），构建脚本下沉 core，turbo 编排。`src/` 与 core 的 `ios/`、`android/` 迁入 `packages/core`。
- **M2-S2 amap 包成形**
  `AMapAdapter` 源码 + SDK 依赖迁入 `packages/amap`：iOS 新 podspec 携 `AMap3DMap ~> 11.1.200`；Android `build.gradle` 携 `com.amap.api` + `ext.amapSdkVersion`，`javaPackageName` 用 `com.cnmaps.amap` 避冲突。core 的 podspec/gradle **删除** AMap 依赖。
- **M2-S3 example 接两个包 + 接线修复**
  `example/react-native.config.js` 两个 dependency(`../../packages/core`、`../../packages/amap`)；codegen 迁移(§4.4)；iOS post_install arm64 排除覆盖 amap 的 pod；Android manifest 去重 + Jetifier 校验。

✅ **检查点 B**（见 §6）。

---

## 4. 核心设计决策（评审重点）

### 4.1 事件回传：childId 注册表替代弱引用链
- Host 路由子组件挂载时，向模型注入**稳定 childId**（用子组件的 react tag / identifier）。
- `adapter.addMarker(model)` 内部建立 **SDK 对象 ↔ childId** 映射。
- SDK 回调（点击/拖拽/区域变化）→ Adapter 经 `delegate` 上报 `(childId, payload)` → Host 按 childId 找到子组件 → 子组件用自己的 Fabric event emitter 发事件。
- **好处**：event emitter（provider 无关的 Fabric 机制）留在 core；SDK 对象映射只在 Adapter。两端语义一致。

### 4.2 哑子组件的边界
子组件保留：props 解析、Fabric/ViewGroup 外壳、自己的 event emitter、向 Host 暴露 `model()`。
子组件删除：一切 AMap 类型与调用、`overlay`/`overlayRenderer` 返回 AMap 对象。
iOS `RNMapsOverlayView` 协议改为 `- (CNOverlayModel *)overlayModel`；renderer 由 Adapter 依模型创建。

### 4.3 手势与异步命令留在 Host
- 手势 recognizer/Detector 安装在 `adapter.mapView`（Adapter 返回的 UIView/View）上，由 Host 负责——provider 无关。
- 异步命令（snapshot）：Adapter 暴露 `takeSnapshot(opts, completion)`；Host 把 completion 包成 `onCommandResult` Fabric 事件。

### 4.4 codegen 全留在 core
- 10 个 Fabric 组件 + TurboModule 的 `codegenConfig` 随 `src` 迁入 `packages/core/package.json`，`jsSrcsDir` 保持 `"src"`（相对 core 包根）。
- 根 `package.json` **删除** `codegenConfig`。amap 包**无** Fabric 组件、无 codegenConfig。
- 校验：`example` 的 metro `root` 与 `react-native.config.js` 指向 `packages/core`，确保 pod install/gradle 的 codegen 定位到 `packages/core/src`。

### 4.5 amap 注册机制
- iOS：`CNAMapAdapter +load` 调 `[CNMapAdapterRegistry registerAdapterClass:self]`，autolink 进 App 即触发，宿主零代码。
- Android：amap 包提供一个 `ReactPackage`（view managers / modules 返回空），在其加载路径里 `CnMapAdapterRegistry.register(AMapAdapterFactory)`。
- 兜底：core 在无任何已注册 Adapter 时，`__DEV__` 抛明确错误（"未安装地图适配器包，请安装 react-native-cn-maps-amap"），而非静默白屏。

---

## 5. 风险与缓解

| # | 风险 | 里程碑 | 缓解 |
|---|---|---|---|
| R1 | **事件回传弱引用链改造出错**，导致 marker 点击/拖拽事件丢失 | M1-S3 | 用 childId 注册表(§4.1)；逐覆盖物迁移、每类迁完即在 example 验事件；优先迁 Marker 打通范式再推广 |
| R2 | **iOS 覆盖物协议改造**牵连 renderer 创建时机，overlay 不显示 | M1-S3 | renderer 创建集中进 Adapter 的 `mapView:rendererForOverlay:`；保持「形态改变 = remove+add 重建」既有语义 |
| R3 | **arm64 模拟器排除失效**，Apple Silicon 上 example 链接失败 | M2-S3 | post_install 遍历**所有** pod target（含 amap 引入的 AMap3DMap/AMapFoundation）设 `EXCLUDED_ARCHS[...]=arm64`；保持 example Podfile 现有那段不删 |
| R4 | **codegen jsSrcsDir 路径错乱**，生成空/错的 RNMapsSpecs | M2-S1/S3 | 根删 codegenConfig；core 内 `jsSrcsDir:"src"`；先 `yarn clean` 再重生成；校验生成物路径 |
| R5 | **Android manifest 权限合并冲突 / Jetifier 漏改** | M2-S3 | amap 包 manifest 不重复声明 example 已有权限；确认最终 merged manifest；保留 example Jetifier 开关 |
| R6 | **「零行为变化」无原生单测兜底** | M1/M2 | 以 example 双端**回归矩阵**(spec §Testing)为主安全网；加 CI grep 断言守护 core 无 AMap 引用 |
| R7 | example 需真机/模拟器构建才能验收，依赖本机环境 | M1/M2 | 检查点需在 macOS + iOS 模拟器 + Android 上实跑；若 CI 不具备，需维护者本地过矩阵 |

---

## 6. 验证检查点

**检查点 A（M1 完成，仍单包）**
```sh
yarn test          # 现有用例全绿，未改动用例
yarn typecheck && yarn lint
yarn example ios   # 起 iOS 模拟器
yarn example android
```
- [ ] example 双端跑通 spec §Testing 的 9 类回归矩阵，行为与重构前一致
- [ ] grep：AMap/MAMap/com.amap 仅出现在 `*Adapter` 文件，Host 与子组件文件内为 0

**检查点 B（M2 完成，monorepo）**
```sh
# 在 packages/core 内断言无任何高德引用（spec 验收 #2/#3）
grep -rE 'AMap|MAMap|com\.amap' packages/core ; echo "expect: no matches"
yarn test && yarn typecheck && yarn lint
yarn example ios && yarn example android
```
- [ ] `packages/core` 内高德引用 grep = 0
- [ ] core 的 podspec 无 `AMap3DMap`、core 的 gradle 无 `com.amap.api`
- [ ] example 仅装 `react-native-cn-maps` + `react-native-cn-maps-amap` 即双端跑通全矩阵
- [ ] JS 公开 API / `src/index.tsx` 导出与重构前一致

---

## 7. 已确认决策（评审通过，进 Tasks）

| # | 决策 | 定论 | 对计划的影响 |
|---|---|---|---|
| D1 | 里程碑切分 | **两段式**：M1 原地逻辑重构(单包) → M2 物理拆包(monorepo)，各自独立验收 | Tasks 分两组，M2 依赖 M1 检查点 A 通过 |
| D2 | 验收环境 | **我用 run 技能驱动模拟器** 实跑 example 双端回归矩阵（iOS 模拟器 + Android） | 检查点 A/B 由我执行；R7 缓解为「需本机模拟器/构建环境就绪」 |
| D3 | iOS podspec 发布形态 | **同 repo 两个 podspec**、同一 tag，宿主按需选装 | M2-S2 两个 podspec 的 `source` 同指本 repo；发布流程不分叉 |
| D4 | Android `javaPackageName` | **`com.cnmaps.amap`** | M2-S2 amap `build.gradle` 用此命名空间，与 core codegen 命名空间隔离 |

---

*据此拆 Phase 3 Tasks（每个任务 ≤5 文件、带验收与验证步骤）见 [`p1-tasks.md`](./p1-tasks.md)。*
