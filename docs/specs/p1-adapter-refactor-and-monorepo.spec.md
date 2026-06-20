# Spec: P1 —— Adapter 重构 + Monorepo 拆分（AMap-only，零行为变化）

> 状态：**待评审（Phase 1 / Specify）** —— 评审通过前不进入 Plan / Tasks / 实现
> 架构依据：[`../MULTI_PROVIDER_ARCHITECTURE.md`](../MULTI_PROVIDER_ARCHITECTURE.md)
> 范围：方案 B 路线图的 **P1**，并在本期一并完成 monorepo 物理拆分

---

## Objective（目标）

把原生层从「与高德深度耦合的智能子组件」重构成「**与厂商无关的 Adapter 模式**」，并把仓库**物理拆分成 monorepo**（`core` + `amap` 两包），且**对外行为零变化**。

这是让「未来加百度 / 腾讯 = 写一个适配器包」成立的结构性地基。本期只搬代码、不加能力。

**为什么现在做这两件事在一起**：重构本就要大范围搬动原生代码，顺势把高德专属代码抽进独立包最干净，避免「先重构再拆包」两次触碰同一批文件。

**用户故事**：
- 作为库维护者，重构后核心包不含任何地图 SDK，加新厂商只需新增一个适配器包。
- 作为现有使用者，升级到本版本后，**所有现有功能行为完全不变**（只是依赖从一个包变成 `core` + `amap` 两个包）。

**明确不在本期范围（P2–P4，另开 spec）**：
- ❌ 坐标层 provider-aware（`toProviderCoordinate` 仍以 gcj02 为目标）
- ❌ 引入任何第二个地图 SDK（百度 / 腾讯）
- ❌ 删除 `MapView.tsx:150` 的 provider 警告回退、改造 `provider` prop 语义
- ❌ 任何 JS 公开 API / 导出的变化

---

## Tech Stack

- **JS**：TypeScript，React 19.2，React Native 0.85，**New Architecture（Fabric + TurboModule）only**
- **iOS**：Obj-C / Obj-C++（`.mm`），`AMap3DMap ~> 11.1.200`
- **Android**：Kotlin，`com.amap.api:3dmap-location-search`（`ext.amapSdkVersion`）
- **构建 / 工具**：yarn 4 workspaces、`react-native-builder-bob`、`turbo`（已有 `turbo.json`）、Jest、ESLint、Prettier
- **example**：`react-native-monorepo-config` + `@react-native/metro-config`

---

## Commands

> monorepo 化后，根 `package.json` 从「库本身」变为「私有 workspace 根」，构建脚本下沉到 `packages/core`，根用 turbo 编排。

```sh
# 安装
yarn install

# 构建核心包（bob）
yarn workspace react-native-cn-maps prepare

# 测试 / 类型 / lint（根，turbo 编排各包）
yarn test
yarn typecheck
yarn lint

# 跑 example
yarn example ios          # react-native run-ios
yarn example android      # react-native run-android
yarn example start        # metro
```

验收必须三平台动作齐全：`yarn test` 绿、`yarn example ios` 与 `yarn example android` 均能起且功能不回归。

---

## Project Structure（目标 monorepo 结构）

```
react-native-cn-maps/                 (私有 workspace 根：turbo + yarn workspaces)
├─ package.json                       (private; workspaces: ["packages/*","example"])
├─ turbo.json
├─ packages/
│  ├─ core/                           → npm: react-native-cn-maps
│  │   ├─ src/                        (现有 src/ 整体迁入，JS 公开 API 不变)
│  │   ├─ ios/
│  │   │   ├─ RNMaps*.{h,mm}          (Fabric 组件 → 改哑子组件 + Host 容器)
│  │   │   ├─ CNMapAdapter.h          (适配器协议，新增)
│  │   │   ├─ CNMapAdapterRegistry.*  (注册表，新增)
│  │   │   └─ RNMapsModule.*          (隐私 TurboModule → fan-out)
│  │   ├─ android/src/main/java/com/cnmaps/
│  │   │   ├─ MapView.kt / *Manager   (Host 容器 + 哑子组件)
│  │   │   ├─ adapter/CnMapAdapter.kt (接口 + Registry，新增)
│  │   │   └─ RNMapsModule.kt / MapsPackage.kt
│  │   └─ CnMaps.podspec              ← 删除 AMap3DMap 依赖
│  ├─ amap/                           → npm: react-native-cn-maps-amap
│  │   ├─ ios/
│  │   │   ├─ CNAMapAdapter.{h,mm}    (实现 CNMapAdapter，承载现有高德逻辑)
│  │   │   └─ CnMapsAMap.podspec      (依赖 AMap3DMap ~> 11.1.200)
│  │   └─ android/
│  │       ├─ src/main/java/.../amap/ (AMapAdapter + ReactPackage 注册)
│  │       └─ build.gradle            (依赖 com.amap.api:3dmap-location-search)
├─ example/                           (依赖 core + amap 两个 workspace 包)
└─ docs/
```

---

## Code Style

沿用现有约定，不改风格：

- **iOS**：Fabric 组件保留 `RNMaps*` 前缀；适配器协议 / 新类型用 `CN*` 前缀。
- **Android**：包名 `com.cnmaps`；适配器相关放 `com.cnmaps.adapter`，厂商实现放各自包。
- **JS/TS**：Prettier 现有配置（`singleQuote`、`tabWidth: 2`、`trailingComma: es5`）。

适配器实现示例（厂商包侧应长这样）：

```objc
// packages/amap/ios/CNAMapAdapter.mm
@implementation CNAMapAdapter
+ (NSString *)providerName { return @"amap"; }
+ (void)load { [CNMapAdapterRegistry registerAdapterClass:self]; }  // 自注册，宿主零代码
- (CNCoordinateSystem)nativeCoordinateSystem { return CNCoordinateSystemGCJ02; }
- (id<CNOverlayHandle>)addMarker:(CNMarkerModel *)model { /* 现有 MAAnnotation 逻辑搬到这里 */ }
@end
```

```kotlin
// packages/amap/android/.../amap/AMapAdapter.kt
class AMapAdapter(context: ThemedReactContext) : CnMapAdapter {
  override val providerName = "amap"
  override val nativeCoordinateSystem = CnCoordinateSystem.GCJ02
  override fun addMarker(model: CnMarkerModel): OverlayHandle { /* 现有 com.amap 逻辑 */ }
}
```

---

## Testing Strategy

本期是「零行为变化」的结构重构，安全网分两层：

1. **JS 单元测试（自动，硬门槛）**：`src/__tests__/` 现有用例（coordinate / commands / overlay / heatmap / polyline / marker / geojson / tile / wmstile / animatedRegion）全部属 JS 层、与厂商无关，**必须原样全绿**，不允许修改用例去迁就重构。
2. **example 功能回归矩阵（手动 / 真机，主安全网）**：原生层本仓库无单测，故以 example 逐项验证为准——iOS 模拟器 + Android 各跑一遍：

   | 验证项 | iOS | Android |
   |---|---|---|
   | 地图加载 / 隐私合规生效 | ☐ | ☐ |
   | Marker（默认 / 彩色 / image / 自定义 view / 可拖拽） | ☐ | ☐ |
   | Callout（含 tooltip / subview 点击） | ☐ | ☐ |
   | Polyline / Polygon(含 holes) / Circle | ☐ | ☐ |
   | Overlay(ground) / UrlTile / LocalTile / WMSTile | ☐ | ☐ |
   | Heatmap | ☐ | ☐ |
   | Geojson | ☐ | ☐ |
   | ref 命令（animateToRegion / fitToCoordinates / takeSnapshot / getCamera / 投影） | ☐ | ☐ |
   | 事件（onPress / onRegionChange / onMarkerPress / …） | ☐ | ☐ |

3. **结构守护（grep 断言）**：`packages/core` 内 grep `AMap|MAMap|com\.amap` 结果为 **0**；该断言可放进 CI。

---

## Boundaries

**Always（必须做）**
- 保持 JS 公开 API 与 `src/index.tsx` 导出**逐字节不变**（`git diff` 导出面为空）。
- 现有 Jest 用例保持全绿，不改用例迁就实现。
- 提交信息：**单行短消息、不带 co-author / Co-Authored-By**（仓库约定）。
- 「完成」前必须在 iOS + Android 双端跑通 example 回归矩阵。

**Ask first（先问）**
- 升级 / 改动 AMap SDK 版本。
- 新增任何依赖。
- 改 codegen 组件名或 `*NativeComponent.ts` spec 形状。
- 改 example 的对外结构 / 启动方式。
- 任何会被 JS 观察到的行为变化。

**Never（禁止）**
- 本期引入第二个地图 SDK。
- 改坐标转换语义（`coordinate.ts` 数学不动）。
- 删除 / 跳过失败测试来「让它过」。
- 提交任何密钥。

---

## Success Criteria（可验收的成功定义）

1. 仓库为 yarn-workspaces monorepo：`packages/core`（npm 名 `react-native-cn-maps`）+ `packages/amap`（npm 名 `react-native-cn-maps-amap`）+ `example`。
2. **core 不含任何地图 SDK 依赖**：`CnMaps.podspec` 无 `AMap3DMap`；core 的 `build.gradle` 无 `com.amap.api`。二者均迁入 `amap` 包。
3. `packages/core` 内 `grep -rE 'AMap|MAMap|com\.amap'` 返回 0；所有高德类引用只存在于 `packages/amap`。
4. core 定义并使用 `CNMapAdapter` 协议（iOS）/ `CnMapAdapter` 接口（Android）+ Registry + Host 容器；覆盖物子组件退化为「哑数据持有者」。
5. `amap` 包在加载时自注册适配器（iOS `+load` / Android `ReactPackage`），**宿主 App 无需任何注册代码**。
6. `yarn test` 全绿（用例未改）；`yarn typecheck`、`yarn lint` 无错。
7. example 在 **iOS 模拟器与 Android 均能构建并运行**，§Testing 的回归矩阵逐项与重构前一致。
8. JS 公开 API / 导出不变；`provider` 仍仅 `amap` 生效，`MapView.tsx:150` 的警告回退**原样保留**（其改造属 P2）。

---

## Open Questions（需在 Plan 阶段敲定）

1. **跨 workspace 的 autolinking**：example 如何发现 `packages/amap` 的原生模块？需确认 iOS Podfile autolink、Android `settings.gradle`、`example/react-native.config.js` 与 metro `root` 的解析路径。
2. **`OverlayHandle` 生命周期归属**：哑子组件卸载与 Host 容器 diff 的时序，谁负责 `removeOverlay` 防泄漏。
3. **隐私 TurboModule 落位**：本期保持在 core（向 Registry fan-out），高德的 `updatePrivacy*` 实现搬进 `amap` 适配器——确认这样不破坏现有隐私时序（`555570` 不复现）。
4. **只装 core 不装 amap 的兜底**：宿主漏装适配器包时，应给出明确 `__DEV__` 运行时错误，而非静默白屏——是否在 core 加一层无适配器检测。
5. **codegen 归属**：`codegenConfig`（现于根 `package.json`）随 core 迁移后，example 的 codegen 解析是否仍正确。

---

*评审通过后，再据此生成 Phase 2 实现计划（Plan）。本 spec 为活文档，决策变更先改此处再改代码。*
