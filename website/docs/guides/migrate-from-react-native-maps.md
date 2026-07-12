---
id: migrate-from-react-native-maps
title: 从 react-native-maps 迁移
sidebar_label: 从 rn-maps 迁移
description: 把现有 react-native-maps 项目迁移到 react-native-cn-maps：改 import、选厂商、声明坐标系与隐私合规。
---

# 从 react-native-maps 迁移

本库的 API 刻意对齐 [`react-native-maps`](https://github.com/react-native-maps/react-native-maps)（下称 **rn-maps**）。多数迁移只需**改一行 import**，真正需要动脑的只有两点：**坐标系**和**隐私合规**。

## TL;DR

```diff
- import MapView, { Marker, Polyline } from 'react-native-maps';
+ import MapView, { Marker, Polyline } from 'react-native-cn-maps';
```

```diff
  <MapView
-   provider={PROVIDER_GOOGLE}
+   provider="amap"
+   coordinateSystem="wgs84"   // 声明你的坐标来源系
    style={{ flex: 1 }}
    initialRegion={region}
  >
```

外加一步：应用启动、用户同意隐私政策后调用一次 [`setPrivacyConsent`](./privacy-compliance.md)。

## 步骤

### 1. 换包

```sh
yarn remove react-native-maps
yarn add react-native-cn-maps react-native-cn-maps-amap   # 或 baidu / tencent
```

`import` 路径从 `react-native-maps` 改为 `react-native-cn-maps`。组件名（`MapView`、`Marker`、`Callout`、`Polyline`、`Polygon`、`Circle`、`Overlay`、`Heatmap`、`Geojson`、`UrlTile` / `LocalTile` / `WMSTile`）保持一致。

### 2. 改 provider

rn-maps 用 `PROVIDER_GOOGLE` / `PROVIDER_DEFAULT`；本库用字符串 `"amap"` / `"baidu"` / `"tencent"` / `"mapkit"`：

```diff
- import { PROVIDER_GOOGLE } from 'react-native-maps';
- <MapView provider={PROVIDER_GOOGLE} />
+ <MapView provider="amap" />
```

> 为便于迁移，本库也**保留** `PROVIDER_DEFAULT` / `PROVIDER_GOOGLE` 常量导出（映射到默认厂商），旧代码不改也能编译。但推荐新代码直接用字符串 provider。

见[选择地图厂商](../getting-started/choosing-provider.md)。

### 3. 声明坐标系（**迁移的关键**）

rn-maps 接 Google Maps，坐标是 WGS-84，不做加偏。国内地图厂商用 GCJ-02 / BD-09。用 `coordinateSystem` 声明**你现有坐标数据的来源系**——如果你之前喂给 Google Maps 的是 GPS 坐标，那就是 `wgs84`：

```tsx
<MapView provider="amap" coordinateSystem="wgs84" /* ... */ />
```

这样你**不用改任何一条坐标数据**，库会自动转换。若忽略这一步，标记和视野会整体偏移。务必读[坐标系专题](./coordinate-systems.md)。

### 4. 加隐私合规

这是 rn-maps 没有、国内 SDK 必须的一步。用户同意后、地图挂载前调用一次：

```tsx
import { setPrivacyConsent } from 'react-native-cn-maps';
setPrivacyConsent({ agreed: true, contains: true, shown: true });
```

见[隐私合规](./privacy-compliance.md)。

### 5. 配原生 key

删掉 Google Maps 的 API key 配置，换成所选厂商的 SDK key。见[原生配置](../native-setup/amap.md)。

## API 差异清单

大部分 props / 方法与 rn-maps 同名同义。已知需要注意的差异：

| 主题 | rn-maps | 本库 |
|---|---|---|
| provider | `PROVIDER_GOOGLE` / `PROVIDER_DEFAULT` 常量 | 字符串 `"amap"` 等（也保留常量别名） |
| 坐标系 | 隐含 WGS-84 | 显式 `coordinateSystem`，自动转换 |
| 隐私 | 无 | 必须 `setPrivacyConsent` |
| `onRegionChange(Complete)` 回调 | `(region, details)` 两个参数 | **事件信封** `(e) => e.nativeEvent.region` / `e.nativeEvent.isGesture` |
| Web / `provider="google"` | 支持 | 不支持（本库定位中国厂商） |
| 部分能力的厂商差异 | — | 见[厂商支持矩阵](./provider-matrix.md) |

:::warning 事件回调形态不同
本库所有事件回调统一是「事件信封」`{ nativeEvent: {...} }`，从 `e.nativeEvent` 取值。如果你的 rn-maps 代码写的是 `onRegionChangeComplete={(region) => ...}`，需改为 `onRegionChangeComplete={(e) => { const region = e.nativeEvent.region; }}`。
:::

## 类型别名（少改代码）

本库为从 rn-maps 迁移的代码保留了一批**类型别名**，让你只改 import 路径、不改类型名：`Provider`（= `MapProvider`）、`ChangeEvent`（= `RegionChangeEvent`）、`FitToOptions`、`Frame`、`ClickEvent`、`PolygonPressEvent` 等。新代码建议用本库的规范名（见 [API 参考](../api/index.md)）。

## 迁移检查清单

- [ ] `react-native-maps` → `react-native-cn-maps` + 厂商包
- [ ] `import` 路径已替换
- [ ] `provider` 改为厂商字符串
- [ ] 加上 `coordinateSystem`，用地标验证无偏移
- [ ] 应用启动加 `setPrivacyConsent`
- [ ] 原生 key 从 Google 换成厂商 SDK
- [ ] 事件回调改为读 `e.nativeEvent`
- [ ] 逐一核对用到的能力在目标厂商是否支持（[支持矩阵](./provider-matrix.md)）
