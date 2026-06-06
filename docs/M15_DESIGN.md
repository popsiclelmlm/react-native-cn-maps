# M15 设计:MapView 命令补全

> 对应 [RNM_PARITY_PLAN.md](RNM_PARITY_PLAN.md) M15(P1)。补齐 RNM 常用但还缺的 ref 命令。复用 M6 的「command(+ requestId / onCommandResult)」机制。

## 范围调整

- **`setMapBoundaries(northEast, southWest)`** —— void 命令(限制可视范围)。
- **`getMarkersFrames(onlyVisible?)`** —— query 命令(返回各 marker 屏幕坐标/frame)。
- ~~`setRegion`~~ —— **不做**:RNM 并没有命令式 `setRegion`(region 是受控 prop);即时设区域用 `<MapView region={...}>` 或 `animateToRegion(r, 0)`。已在 [MIGRATION](MIGRATION_FROM_RN_MAPS.md) 口径里保持一致。

## setMapBoundaries

```
setMapBoundaries(viewRef, neLat, neLng, swLat, swLng)  // void
```
- JS facade 按 `coordinateSystem` 把 ne/sw 转 gcj02 后下发。
- Android:`aMap.setMapStatusLimits(LatLngBounds(sw, ne))`。
- iOS:`_mapView.limitRegion`(由 ne/sw 算 center + span)。

## getMarkersFrames

```
getMarkersFrames(viewRef, requestId, onlyVisible)  // 结果走 onCommandResult
```
回传 `data = { <identifier>: { point: {x,y}, frame: {x,y,width,height} } }`(屏幕坐标,单位 dp/point)。JS `query` 直接把整个对象 resolve。

- Android:遍历 `features` 里的 `MarkerView`(有 `identifier` 才计入),`aMap.projection.toScreenLocation(position())` 得屏幕像素 → 除以 density;`onlyVisible` 时过滤掉落在地图视口外的点。
- iOS:遍历 `_markers`,读 `marker.annotation.identifier/.coordinate`,`[_mapView convertCoordinate:toPointToView:]` 得 point。
- **best-effort / 文档化**:`frame.width/height` 取 0(AMap 不直接暴露 annotation view 的 frame 尺寸);`point` 准确,`frame` 以 point 为原点。

## 三层落点

- **JS**:`MapViewNativeComponent.ts` 增加 `setMapBoundaries` / `getMarkersFrames` 命令 + `supportedCommands`;`MapView.tsx` 命令式 handle 实现两者。
- **Android**:`MapViewManager` 增加两个 override → `MapView.setMapBoundariesValue(...)` / `MapView.getMarkersFramesResult(...)`。
- **iOS**:`RNMapsMapView.mm` 增加 `- (void)setMapBoundaries:...` / `- (void)getMarkersFrames:...`。
- **example**:复用现有 marker;加一个按钮:`getMarkersFrames` 打日志、`setMapBoundaries` 限制到上海周边。
- **测试**:`commands.test.ts` 追加断言 `setMapBoundaries` / `getMarkersFrames` 在 commands 中。

## 验收(同步回 RNM_PARITY_PLAN.md M15)

- [ ] 三层落地 + codegen/typecheck/lint/jest 通过
- [ ] `setMapBoundaries` 限制可视范围
- [ ] `getMarkersFrames` 返回各 marker 屏幕坐标
- [ ] Android 真机验证 / iOS 真机验证
