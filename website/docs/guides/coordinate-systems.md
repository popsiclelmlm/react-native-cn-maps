---
id: coordinate-systems
title: 坐标系专题（WGS-84 / GCJ-02 / BD-09）
sidebar_label: 坐标系专题
description: 理解中国地图的坐标加偏，正确声明 coordinateSystem，避免标记与视野整体偏移。
---

# 坐标系专题

中国大陆的地图数据受法规约束存在**坐标加偏**。用错坐标系是国内地图开发最常见的坑——表现为标记、折线、视野**整体偏移几十到几百米**。本库在 JS 层自动转换，你只需**如实声明输入坐标属于哪个系**。

## 三种坐标系

| 坐标系 | 俗称 | 谁在用 |
|---|---|---|
| **WGS-84** | 地球坐标 / GPS 原始坐标 | GPS 硬件、`expo-location`、多数国际数据源、Google Maps |
| **GCJ-02** | 火星坐标 / 国测局加偏 | 高德、腾讯、华为 Map Kit（及国内大部分地图） |
| **BD-09** | 百度坐标 | 百度地图（在 GCJ-02 上再加一层偏移） |

关键事实：**同一个真实位置，在三种坐标系下的经纬度数值不同**。把一个 WGS-84 的点直接丢给高德地图，就会偏。

## 本库怎么处理

你在 `<MapView coordinateSystem="...">` 声明**你传入的坐标**属于哪个系；库把它转换到当前 `provider` 的**原生坐标系**，事件回调再转换回你声明的系。整个过程在 JS 层完成。

```tsx
// 我的坐标是 GPS 原始值（wgs84），地图用高德（原生 gcj02）
<MapView provider="amap" coordinateSystem="wgs84" /* ... */ />
// 传进去的 wgs84 → 库转成 gcj02 给高德；onPress 返回的坐标 → 转回 wgs84
```

各厂商的原生坐标系（无需你记，声明 `coordinateSystem` 即可）：

| provider | 原生坐标系 |
|---|---|
| `amap`（高德） | GCJ-02 |
| `tencent`（腾讯） | GCJ-02 |
| `mapkit`（华为） | GCJ-02 |
| `baidu`（百度） | BD-09 |

转换以 GCJ-02 为枢纽：`wgs84 ↔ gcj02 ↔ bd09`。

## 该给 coordinateSystem 填什么？

**填你的坐标数据的来源系，而不是地图厂商的系。**

| 你的坐标来自…… | 填 |
|---|---|
| GPS / 定位 API（`expo-location`、`react-native-geolocation`） | `wgs84` |
| 高德 / 腾讯 的接口或后台 | `gcj02` |
| 百度 的接口或后台 | `bd09` |
| 说不清 / 混合来源 | 先按最可能的来源填，再用「[怎么判断偏没偏](#怎么判断偏没偏)」验证 |

:::tip 一致性最重要
一个 `<MapView>` 子树内的所有坐标（`initialRegion`、`<Marker>`、`<Polyline>`……）都被当作同一个 `coordinateSystem`。不要在同一张地图里混用不同来源系而不转换。
:::

## 境外坐标不转换

转换算法只在中国大陆范围内加偏。当坐标落在中国大陆经纬度范围之外时，`wgs84 ↔ gcj02` 转换**原样返回**（境外 GCJ-02 与 WGS-84 一致）。所以海外坐标不受影响，但也意味着港澳台及边境地区可能有细微差异。

## 怎么判断偏没偏

1. 找一个你**确定**的地标（如某座桥、某个路口）。
2. 在地图上放一个 `<Marker>`，坐标用该地标的已知经纬度。
3. 看标记是否精准落在地标上：
   - **精准** → 坐标系填对了。
   - **整体偏移一两百米且方向一致** → `coordinateSystem` 填错了，换一个系再试（最常见是把 `wgs84` 误填成 `gcj02`）。

## 需要手动转换时

绝大多数场景交给 `coordinateSystem` 即可。若你需要在地图之外自己转换（例如把用户位置存库前统一成 WGS-84），坐标转换逻辑位于核心包 `packages/core/src/coordinate.ts`，实现了 `wgs84ToGcj02` / `gcj02ToWgs84` / `bd09ToGcj02` / `gcj02ToBd09`（`gcj02ToWgs84` 用三次牛顿迭代把残差压到亚厘米级）。

## 小结

- 加偏是法规导致的客观现实，不是 bug。
- 只需**如实声明** `coordinateSystem` = 你的坐标来源系，其余交给库。
- 偏移排查第一步永远是：**检查 `coordinateSystem` 填得对不对**。
