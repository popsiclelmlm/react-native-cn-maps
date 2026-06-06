# react-native-maps 对标补全计划

> 目标:在已完成的 M1–M10 基础上,补齐 `react-native-maps`(下称 RNM)example(52 个示例)仍未覆盖的 API,使"改 import 即可迁移"的承诺尽量完整。
>
> 范围:仅适配国内 provider(首发高德 AMap),仅 React Native 新架构(Fabric)。Apple 专属能力(`legalLabelInsets`/`appleLogoInsets` 等)不在对标范围。
>
> 配套阅读:能力对照见 [MIGRATION_FROM_RN_MAPS.md](MIGRATION_FROM_RN_MAPS.md);总体路线见 [ROADMAP.md](ROADMAP.md)。

## 图例

✅ 完成 · 🚧 进行中 · ⏸ 暂缓 · ⬜ 未开始

每个里程碑遵循全局原则:**JS 门面按 RNM 命名 → native 适配 AMap;每个里程碑必须有 example 演示页 + 至少一个单测/快照;无法 1:1 实现的能力 best-effort 映射 + `__DEV__` warning,不改 API 形状。**

---

## 进度总览

| 里程碑 | 能力 | 优先级 | 状态 | 对标 RNM 示例 |
|--------|------|--------|------|----------------|
| M11 | UrlTile / LocalTile(自定义瓦片) | P0 | ✅ | CustomTiles / CustomTilesLocal / CacheURLTiles |
| M12 | Overlay(图片覆盖物) | P0 | ✅ | ImageOverlayWith{Assets,URL,Bearing} |
| M13 | takeSnapshot(地图截图) | P1 | ✅ | TakeSnapshot |
| M14 | Geojson(纯 JS 渲染) | P1 | ✅ | Geojson |
| M15 | MapView 命令补全 | P1 | ✅ | FitToCoordinates / MapBoundaries / DisplayLatLng |
| M16 | Polyline 渐变 + 线型补全 | P2 | ✅ | GradientPolylines(Functional) |
| M17 | Heatmap(热力图) | P2 | ✅ | HeatMap |
| M18 | WMSTile | P2 | ✅ | WMSTiles / CacheWMSTiles |
| M19 | 室内地图 + KML | P2 | ⏸ | IndoorMap / MapKml |

> 不对标:`setNativeProps`(旧架构,Fabric 用 state)、`provider=google`、Apple 专属 insets。

> ✅ **M11–M18 已通过 Android 真机验证(2026-06-06)**。验证中修复了 2 个真机专属 bug:V1(离屏 marker/overlay 的 `post` 不执行 → 图片/自定义内容不显示)、V2(AMap 热力图依赖旧 Support 库 → host 需 `android.enableJetifier=true`)。**iOS 仍待首次真机编译验证(H-arch)。** 详见 [CODE_REVIEW_FINDINGS.md](CODE_REVIEW_FINDINGS.md)。

---

## M11 — UrlTile / LocalTile(自定义瓦片) · P0

**目标**:支持自定义底图瓦片(在线模板 URL + 本地文件),含离线缓存。当前两个组件均为 stub。

- JS:把 `MapUrlTile` / `MapLocalTile` 从 stub 改为真 `codegenNativeComponent`,作为 `<MapView>` 子 host component。
- props(UrlTile):`urlTemplate`(`{x}{y}{z}`)、`zIndex`、`maximumZ`/`maximumNativeZ`、`tileSize`/`doubleTileSize`、`tileCachePath`、`tileCacheMaxAge`、`offlineMode`、`opacity`。
- props(LocalTile):`pathTemplate`(`{z}{x}{y}`)、`tileSize`、`zIndex`。
- AMap 对应:
  - Android:`aMap.addTileOverlay(TileOverlayOptions().tileProvider(UrlTileProvider(...)))`;本地用自定义 `TileProvider` 读文件。
  - iOS:`MATileOverlay`(在线)/ 自定义 `MATileOverlay` 子类(本地)+ `[mapView addOverlay:]`。
- 验收:
  - [x] 三层落地(JS spec/门面 + Android View/Manager + iOS 组件)+ codegen/typecheck/lint/jest 通过
  - [x] UrlTile 在线瓦片(example 演示页:OSM 栅格开关)
  - [x] LocalTile 本地瓦片(文件系统 / assets)
  - [x] 单测(sentinel 一致性)
  - [ ] Android 真机验证(瓦片实际显示)
  - [ ] iOS 真机验证
  - [ ] `offlineMode` + 缓存路径(best-effort,待验证)
  - 详细设计见 [M11_DESIGN.md](M11_DESIGN.md)

## M12 — Overlay(图片覆盖物) · P0

**目标**:把一张图片按地理 bounds 贴到地图上,支持旋转。当前为 stub。

- JS:`MapOverlay` 改真组件;props:`image`(require/uri)、`bounds`(`[[neLat,neLng],[swLat,swLng]]`)、`bearing`、`opacity`、`zIndex`。
- AMap 对应:
  - Android:`aMap.addGroundOverlay(GroundOverlayOptions().image(...).positionFromBounds(LatLngBounds).bearing(...))`。
  - iOS:`MAGroundOverlay`(`initWithBounds:icon:`)+ 自定义 renderer。
- 验收:
  - [x] 三层落地(JS spec/门面 + Android View/Manager + iOS 组件)+ codegen/typecheck/lint/jest 通过
  - [x] 本地图片 + URL 图片两种来源(JS `resolveAssetSource` + native 异步加载)
  - [x] `bearing` 旋转 + `opacity`(transparency)+ bounds 归一化
  - [x] example 演示页(image ground overlay 开关)+ 单测(归一化 + sentinel)
  - [ ] Android 真机验证 / iOS 真机验证(iOS `MAGroundOverlayRenderer` 符号待确认)
  - 详细设计见 [M12_DESIGN.md](M12_DESIGN.md)

## M13 — takeSnapshot(地图截图) · P1

**目标**:`mapRef.current.takeSnapshot({width,height,region,format})` → 返回图片 URI。

- JS:走 M6 的 command + `onCommandResult` Promise 回传模式(返回临时文件路径或 base64)。
- AMap 对应:
  - Android:`aMap.getMapScreenShot(AMap.OnMapScreenShotListener)`,写入临时文件后回传路径。
  - iOS:`[mapView takeSnapshotInRect:withCallback:]`。
- 验收:
  - [x] 三层落地(command + onCommandResult Promise)+ codegen/typecheck/lint/jest 通过
  - [x] file / base64 两种返回 + 可缩放(width/height)+ png/jpg
  - [x] example "takeSnapshot" 按钮 + `<Image>` 预览 + 单测(commands 含 takeSnapshot)
  - [ ] Android 真机验证(返回可用 uri,`<Image>` 显示) / iOS 真机验证
  - [ ] `region` 指定区域截图(本期忽略,文档化)
  - 详细设计见 [M13_DESIGN.md](M13_DESIGN.md)

## M14 — Geojson(纯 JS 渲染) · P1

**目标**:`<Geojson geojson={FeatureCollection} />` 渲染点/线/面。**无需新原生代码**——解析后复用已有的 Marker/Polyline/Polygon。

- JS:`MapGeojson` 改为解析 GeoJSON → 渲染对应子组件;支持 `strokeColor`/`fillColor`/`strokeWidth`/`color`/`zIndex`/`markerComponent` 等覆盖样式。
- 坐标系:按 `<MapView coordinateSystem>` 在 JS 层统一转换(沿用现有 coordinate.ts)。
- 验收:
  - [x] 纯 JS 实现(`flattenGeojson` + 复用 Marker/Polyline/Polygon)+ typecheck/lint/jest 通过
  - [x] Point / MultiPoint / LineString / MultiLineString / Polygon(含内孔)/ MultiPolygon / GeometryCollection / Feature / FeatureCollection
  - [x] 样式 props(stroke/fill/dash/zIndex/marker 外观)生效
  - [x] example "Geojson" 开关 + 单测(各几何类型 + 畸形输入 → `[]`)
  - [ ] Android 真机验证(低风险,复用已落地组件)
  - 详细设计见 [M14_DESIGN.md](M14_DESIGN.md)

## M15 — MapView 命令补全 · P1

**目标**:补齐 RNM 常用但我们还缺的 ref 命令。

- `setRegion(region)` —— 即时设区域(Android `moveCamera` 无动画;iOS `setRegion:animated:NO`)。
- `getMarkersFrames(onlyVisible)` —— 取各 marker 屏幕坐标(可基于已有 `pointForCoordinate` + marker 列表在 JS/native 组装)。
- `setMapBoundaries(ne, sw)` —— 限制可视范围(Android `setMapStatusLimits(LatLngBounds)`;iOS `limitMapRect`/`limitRegion`)。
- 验收:
  - [x] `setMapBoundaries` + `getMarkersFrames` 三层落地 + codegen/typecheck/lint/jest 通过
  - [x] example 触发按钮(setMapBoundaries / getMarkersFrames)+ 单测(commands 含新命令)
  - [x] `setRegion` 确认不做(RNM 无此命令式方法;用受控 `region` prop 或 `animateToRegion(r,0)`)
  - [ ] Android 真机验证 / iOS 真机验证
  - 详细设计见 [M15_DESIGN.md](M15_DESIGN.md)

## M16 — Polyline 渐变 + 线型补全 · P2

**目标**:补齐 Polyline 高级线型。

- props:`strokeColors`(逐点渐变)、`lineCap`、`lineJoin`、`miterLimit`。
- AMap 对应:
  - Android:`PolylineOptions.colorValues(list).useGradient(true)`;线帽/连接按 SDK 支持 best-effort。
  - iOS:`MAMultiColoredPolyline` + `MAMultiColoredPolylineRenderer`(`strokeColors`)。
- 验收:
  - [x] 三层落地 + codegen/typecheck/lint/jest 通过
  - [x] `strokeColors` 渐变(Android `colorValues+useGradient` / iOS `MAMultiColoredPolyline`)
  - [x] `lineCap`/`lineJoin` 双端(AMap enums 确认存在)+ `miterLimit`(iOS renderer)
  - [x] example 渐变开关 + 单测(sentinel)
  - [ ] Android 真机验证 / iOS 真机验证
  - 详细设计见 [M16_DESIGN.md](M16_DESIGN.md)

## M17 — Heatmap(热力图) · P2

**目标**:`<Heatmap points={[{latitude,longitude,weight}]} radius opacity gradient />`。当前为 stub。

- AMap 对应:
  - Android:`HeatmapTileProvider` + `TileOverlay`。
  - iOS:`MAHeatMapTileOverlay`。
- 验收:
  - [x] 三层落地(tile-overlay 子组件)+ codegen/typecheck/lint/jest 通过
  - [x] 点集(WeightedLatLng / MAHeatMapNode)+ radius + gradient
  - [x] example "Heatmap" 开关 + 单测(sentinel)
  - [ ] Android 真机验证 / iOS 真机验证
  - 详细设计见 [M17_DESIGN.md](M17_DESIGN.md)

## M18 — WMSTile · P2

**目标**:WMS 瓦片图层。可作为 M11 UrlTile 的变体——JS 层按 `{minX}{minY}{maxX}{maxY}{width}{height}` 计算 bbox URL,复用瓦片通路。

- props:`urlTemplate`(WMS GetMap)、`tileSize`、`maximumNativeZ`、`opacity`、缓存项、`offlineMode`。
- 验收:
  - [x] 复用 UrlTile 通路(`wms` 标志 + EPSG:3857 bbox)+ codegen/typecheck/lint/jest 通过
  - [x] Android(`UrlTileView` bbox 分支)+ iOS(`URLForTilePath:` 子类)
  - [x] example "WMSTile" 开关(OSM-WMS)+ 单测(sentinel)
  - [ ] WMS 图层真机显示(Android / iOS)
  - 详细设计见 [M18_DESIGN.md](M18_DESIGN.md)

## M19 — 室内地图 + KML · P2(暂缓)

**目标**:室内楼层 + KML 导入。AMap 室内能力与 RNM 语义差异较大,KML 无原生直读,优先级最低。

- 室内:`showsIndoors`(已有 prop)+ `showsIndoorLevelPicker` + `setIndoorActiveLevelIndex()` + `onIndoorBuildingFocused`。
  - Android:`aMap.showIndoorMap(true)` + `setOnIndoorBuildingActiveListener`。
- KML:`kmlSrc` + `onKmlReady` + `fitToElements`。AMap 无原生 KML loader → 需 JS 解析 KML 转 overlay(成本高)。
- 验收:
  - [ ] 室内楼层切换(若设备/SDK 支持)
  - [ ] KML best-effort 或明确文档标注不支持

---

## 收尾(贯穿)

- [ ] 每完成一个里程碑,更新本表状态 + [MIGRATION_FROM_RN_MAPS.md](MIGRATION_FROM_RN_MAPS.md) 支持状态(✅/⚠️/❌)。
- [ ] example app 每个新能力新增独立演示页(对标 RNM 同名示例)。
- [ ] 真机/模拟器编译验证(Android 已通,iOS 待首次验证)。
- [ ] 全部 P0/P1 完成后发 0.2.0。

## 建议执行顺序

P0(M11 瓦片 → M12 Overlay)→ P1(M14 Geojson 最易,M13 截图,M15 命令)→ P2 视反馈穿插。其中 **M14 Geojson 几乎纯 JS、成本最低**,可作为热身先做;**M11 瓦片用户面最广**,是补全价值最高的一块。
