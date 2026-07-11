# CnMapsExample · HarmonyOS (RNOH)

完整的鸿蒙示例 = **本目录的 RN JS 工程(锁 0.72.5 + RNOH)** + **DevEco Stage 原生工程(entry/AppScope/...)**。与 iOS/Android 的 `example/`(RN 0.85)**解耦**,各用各的 RN 版本,互不干扰。

> ⚠️ 实验性。RNOH 框架 API、三家地图 SDK API、各 `查证` 项均以真机验证为准。

## ✅ 现状：example 已能在鸿蒙模拟器上运行

在鸿蒙**模拟器**（`hdc -t 127.0.0.1:5555`，arm64-v8a / API 21）上，真实地图 demo（[App.tsx](App.tsx)）
**已正常挂载运行**：provider 切换按钮 + MapView/Marker/Polyline 全部解析、React 树成功 commit、无崩溃。
MapView 区域会渲染一块**可见的 AMap 占位地图**（[../../packages/amap/harmony/src/main/ets/AMapPackage.ets](../../packages/amap/harmony/src/main/ets/AMapPackage.ets) 的 `amapMapBuilder`）——
即 `RN MapView → RNOH RNMapsMapView → CnMapHostComponent → provider builder → ArkUI` 整条渲染链已打通。

要显示**真实底图**还需（当前环境拿不到）：高德鸿蒙地图 SDK **不在公共 ohpm 仓库**（`@amap/amap_lbs_map` 等 404），
需在高德开放平台注册账号下载 `.har` → 加入 `amap/harmony` 的 oh-package 与 entry → 把占位换成真实 `MapComponent`
并在 onMapReady 里 `attachController` → 填平台 Key（`entry/.../module.json5`）→ **真机**。百度/腾讯同理。
> RNOH 细节：ArkTS 自定义地图组件会铺满/盖在 RN 视图之上（盖住顶部按钮），真实接入时需用 zIndex/absolute 让 RN 控件浮在原生地图上层。

打通过程中修了 **4 处**问题：

1. `*NativeComponent.ts`：`codegenNativeComponent` / `codegenNativeCommands` 从深路径默认导入（RNOH 的 `react-native` 入口未导出这俩；附 `codegen-deep-imports.d.ts` 让 strict-API typecheck 仍可解析）。三端通用。
2. `NativeRNMapsModule.ts`：`TurboModuleRegistry.get` 加 try/catch（RNOH 在 C++ 侧缺模块时会**抛异常**而非返回 null，破坏「可空」契约）。三端通用。
3. `metro.config.js`：blockList 增加 `react`，避免库解析到 monorepo 根的 React 19（与 app 的 18.2.0 冲突 → "Invalid hook call / useRef of null"）。
4. **codegen-harmony 接线（关键）**：所有 RNMaps Fabric 组件原先在 RNOH 侧没有 ComponentJSIBinder → JS `requireNativeComponent` 全部报 "not found"（连 MapView 也是，只是被子节点先抛错盖住）。修复链：
   - 库 codegen spec 把 `CodegenTypes.X` 命名空间写法改为裸名 `X`（新增 [../../packages/core/src/codegen-types.ts](../../packages/core/src/codegen-types.ts) re-export）——RNOH 的 RN 0.72 codegen 只认裸名，不认限定名。三端通用、typecheck 通过。
   - `packages/core/package.json` 加 `harmony.codegenConfig`（RNOH 用此键，与 iOS/Android 顶层 `codegenConfig` 分开）。
   - 修补 RNOH CLI 的库扫描使其跟随 symlink（monorepo 的 `file:` 依赖）——见 [../../scripts/harmony/patch-harmony-cli.js](../../scripts/harmony/patch-harmony-cli.js)。
   - 生成的 `RNOHGeneratedPackage.h` 去掉 0.72.38 不存在的 `getComponentName`——见 [../../scripts/harmony/fix-generated-package.js](../../scripts/harmony/fix-generated-package.js)。
   - entry 的 `cpp/PackageProvider.cpp` 返回 `RNOHGeneratedPackage`、`CMakeLists.txt` 编译 `generated/*.cpp`。

### 重新生成 + 构建 + 安装

```bash
cd example/harmony
npm run codegen          # 自动: patch CLI → codegen-harmony → fix 生成的 header
# 命令行构建 HAP（DevEco 自带 hvigorw，首次含原生编译约数分钟，之后增量约 5s）
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
PATH=/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default -p product=default -p buildMode=debug assembleHap --no-daemon
bash ../../scripts/harmony/hm.sh dev   # 装HAP + 起Metro + 转发 + 启动
```

> 纯 RN 冒烟页（[App.smoke.tsx](App.smoke.tsx)，`hm.sh smoke` 切换）可在不接地图时单独验证 RNOH 渲染管线。

## 一键测试工具链：`scripts/harmony/hm.sh`

```bash
bash scripts/harmony/hm.sh doctor   # 体检：hdc/SDK/target/依赖/HAP
bash scripts/harmony/hm.sh deps     # 装 JS 依赖(首次)
bash scripts/harmony/hm.sh dev      # 全自动：装HAP→起Metro→转发8081→启动→看日志
bash scripts/harmony/hm.sh smoke    # 切到纯 RN 冒烟页(不接地图)并重载
bash scripts/harmony/hm.sh app      # 切回真实地图 demo 并重载
bash scripts/harmony/hm.sh shot a.jpeg   # 截图
bash scripts/harmony/hm.sh log      # 实时 RNOH 日志
```

默认自动选模拟器；`HM_TARGET=<序列号> bash scripts/harmony/hm.sh dev` 可指定真机。

## 为什么 JS 侧要独立锁 0.72.5
RNOH `0.72.38` 配套 **react-native 0.72.5**；而仓库根/`example/` 是 0.85(给 iOS/Android)。若混用，Metro 会在 harmony 平台解析失败（如 `ReactDevToolsSettingsManager` 只有 `.android/.ios` 变体）。所以本目录有**自己的 `package.json` + `node_modules`**，并用 RNOH 的 harmony metro 预设。

## 前置
- DevEco Studio + HarmonyOS SDK（compatibleSdkVersion 5.0.0(12)）+ 真机
- Node 18
- 三家高德/百度/腾讯**鸿蒙平台 Key**（填 `entry/src/main/module.json5`）

## 步骤

```bash
# 1) JS 侧:在本目录独立安装(不要用 yarn workspace，避免提升根的 0.85)
cd example/harmony
npm install                     # 装 RN 0.72.5 + @react-native-oh/* + 三家 provider 包

# 2) 生成 codegen C++ 胶水(给 entry 的 externalNativeOptions / CMakeLists)
npm run codegen                 # react-native codegen-harmony  ← 同时验证 0.72 codegen 兼容(P0-C)

# 3) 起 Metro(开发模式,Index.ets 用 MetroJSBundleProvider 连它)
npm run start
hdc -t <connect-key> rport tcp:8081 tcp:8081   # 真机连上后转发(先 `hdc list targets` 拿 key)

# 4) DevEco 打开 example/harmony,配 RNOH SDK 依赖 + 三家 Key,Run 'entry' 到真机
#    (DevEco Run 一般会自动建连+转发,第 3 步的 rport 仅纯命令行连 Metro 时需要)
```

发布包(非开发模式)用：`npm run bundle` 会把 bundle 写进 `entry/src/main/resources/rawfile/`，并把 Index.ets 的 `jsBundleProvider` 换成 `ResourceJSBundleProvider`。

## 分阶段验证（强烈建议按序）
1. **空壳出 RN**：先不接地图 SDK，App 能挂载、不崩、`onMapReady` 日志（地图区域空白，因 `@Builder` 还是占位）。→ 证明 RNOH 集成链路通。
2. **接高德出图**：装高德鸿蒙 SDK、把 `AMapPackage.ets` 的占位 `Column()` 换成真实地图组件 + `attachController`、填 Key。→ P0 高德 go/no-go。
3. **对齐 SDK 方法名**：`hdc hilog` 盯运行时 `xxx is not a function`，逐个把 `AMapAdapter` 的 `controller.xxx()` 对到真实 `.d.ts`。
4. **跑回归矩阵**：九类 × 三家逐项验证。

## 关键文件
- `package.json` / `metro.config.js` / `babel.config.js` —— RN 0.72.5 + RNOH harmony 预设。
- `index.js` / `App.tsx` —— 最小冒烟 App（provider 切换 + marker + polyline + onPress）；跑通后可切到 `example/src/App.tsx` 全量 demo。
- `entry/src/main/ets/RNPackagesFactory.ets` —— 注册 CnMapsPackage + 三家 Package。
- `entry/src/main/ets/pages/Index.ets` —— RNApp（`arkTsComponentNames: [RN_MAPS_MAP_VIEW_TYPE]` + `buildCustomRNComponent` → `CnMapHostComponent`）。
- `entry/src/main/module.json5` —— 三家 Key metadata + 定位权限。

> 库 JS 运行时可在 0.72.5 上跑（`codegenNativeComponent`/`TurboModuleRegistry` 0.72 即有；`CodegenTypes` 是 type-only 导入、运行时擦除）。「0.72 codegen 能否解析」由第 2 步 `npm run codegen` 验。
