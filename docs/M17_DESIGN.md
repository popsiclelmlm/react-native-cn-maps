# M17 设计:Heatmap(热力图)

> 对应 [RNM_PARITY_PLAN.md](RNM_PARITY_PLAN.md) M17(P2)。复用 M11 的「tile-overlay 子 host component」地基:热力图本质是一张由点集生成的 TileOverlay。当前组件为 stub。

## 架构

新增 codegen 子 host component `RNMapsHeatmap`,挂在 `<MapView>` 下:

- **Android**:`HeatmapView` 持有 `TileOverlay`(由 `HeatmapTileProvider` 生成);`attachTo` = `aMap.addTileOverlay(...)`;`detach` = `tileOverlay.remove()`。`MapView.addFeature/removeFeatureAt/destroy` 增加识别。
- **iOS**:`RNMapsHeatmap` 实现既有 `RNMapsOverlayView` 协议(`overlay` = `MAHeatMapTileOverlay`,`overlayRenderer` = `MATileOverlayRenderer`)。

## Props(对标 RNM)

| RNM prop | 传递方式 | Android | iOS |
|---|---|---|---|
| `points: {latitude,longitude,weight?}[]` | JSON 字符串(JS 按 `coordinateSystem` 转 gcj02) | ✅ `WeightedLatLng` | ✅ `MAHeatMapNode` |
| `radius` | Int32(默认 20) | ✅ builder.radius | ✅ node.radius |
| `opacity` | Double(默认 0.6) | ⚠️ best-effort | ⚠️ best-effort |
| `gradient: {colors, startPoints, colorMapSize}` | JSON 字符串(colors 用 CSS 色串) | ✅ `Gradient(int[],float[])` | ✅ `MAHeatMapGradient` |

> `points`/`gradient` 走 JSON 字符串(与 tiles/holes 一致),native 解析;避开 codegen 复杂数组/颜色数组限制。

## native 实现要点

- **Android**:`HeatmapTileProvider.Builder().weightedData(List<WeightedLatLng>).radius(r).gradient(Gradient(colorsInt, startPointsFloat)).build()` → `TileOverlayOptions().tileProvider(provider)`。点带 `weight` → `WeightedLatLng(latLng, weight)`,无则 intensity=1。
- **iOS**:`MAHeatMapTileOverlay`,`overlay.data = [MAHeatMapNode]`(每个 node 设 coordinate/intensity/radius),`overlay.gradient = MAHeatMapGradient(colors, startPoints)`;`overlayRenderer` = `MATileOverlayRenderer`。

## 本期范围与 best-effort

- **核心保证**:点集 + radius + gradient 渲染热力图;Android 双端编译(iOS 待真机)。
- **best-effort / 文档化**:`opacity` 视各 SDK 是否暴露透明度而定;`gradient.colorMapSize` 在 native 端可能被忽略。

## 三层落点

- **JS**:`HeatmapNativeComponent.ts`(codegen)+ `MapHeatmap.tsx`(stub→真组件,点转坐标 + JSON;保留 `__MAP_HEATMAP` sentinel)。
- **Android**:`HeatmapView.kt` + `HeatmapManager.kt`;`MapsPackage` 注册;`MapView` feature 识别。
- **iOS**:`RNMapsHeatmap.{h,mm}`(实现 `RNMapsOverlayView`)。
- **example**:新增 "Heatmap (M17)" 开关,喂一组带权重的点。
- **测试**:`MapHeatmap` sentinel + 点集 JSON 序列化的纯逻辑(或 sentinel 级)。

## 验收(同步回 RNM_PARITY_PLAN.md M17)

- [ ] 三层落地 + codegen/typecheck/lint/jest 通过
- [ ] 点集 + radius + gradient 渲染
- [ ] Android 真机验证 / iOS 真机验证
