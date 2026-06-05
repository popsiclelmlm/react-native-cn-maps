# M11 设计:UrlTile / LocalTile(自定义瓦片)

> 对应 [RNM_PARITY_PLAN.md](RNM_PARITY_PLAN.md) M11(P0)。复用 M5 覆盖物的「子 host component 挂在 MapView 下、父地图拦截挂载」地基,把覆盖物从矢量 overlay 换成**瓦片图层**(tile overlay)。

## 架构

新增两个 codegen 子 host component:`RNMapsUrlTile` / `RNMapsLocalTile`,挂在 `<MapView>` 下,与 Polyline/Polygon/Circle 同样走父地图的挂载拦截:

- **Android**:每个瓦片视图持有一个 `TileOverlay` 句柄。`attachTo(aMap)` 时 `aMap.addTileOverlay(TileOverlayOptions)`;`detach()` 调 `tileOverlay.remove()`。`MapView.addFeature` 增加对两个新 View 的识别。
- **iOS**:瓦片视图持有 `MATileOverlay`,**复用现有 `RNMapsOverlayView` 协议**(`overlay` 返回 `MATileOverlay`,`overlayRenderer` 返回 `MATileOverlayRenderer`)。父地图的 `mountChildComponentView` / `rendererForOverlay:` 已按协议工作,无需改动挂载逻辑。

> 与矢量 overlay 的差异:瓦片是异步按需加载的图层,没有"坐标",所以无坐标系转换;样式只有 zIndex/opacity/zoom 范围/缓存。

## Props(对标 RNM)

**UrlTile**(在线模板瓦片):
| prop | 类型 | 说明 | Android | iOS |
|---|---|---|---|---|
| `urlTemplate` | string | 含 `{x}{y}{z}` 占位 | ✅ | ✅ |
| `minimumZ` / `maximumZ` | number | 缩放范围(超出不请求) | ✅ | ✅ |
| `maximumNativeZ` | number | 超过则放大本地瓦片 | ⚠️ best-effort | ✅ |
| `tileSize` | number | 瓦片像素(默认 256) | ✅ | ✅ |
| `doubleTileSize` | boolean | 512 瓦片 | ⚠️ 映射到 tileSize=512 | ⚠️ |
| `flipY` | boolean | TMS 纵向翻转 | ✅(JS/native 计算 y) | ✅ |
| `opacity` | number | 透明度 | ⚠️ AMap Android 无直接 API | ✅(renderer.alpha) |
| `zIndex` | number | 图层顺序 | ✅ | ⚠️ 按 add 顺序 |
| `offlineMode` | boolean | 仅用缓存 | ⚠️ best-effort | ⚠️ best-effort |
| `tileCachePath` | string | 磁盘缓存目录 | ✅(diskCacheDir) | ⚠️ |
| `tileCacheMaxAge` | number | 缓存有效期(秒) | ⚠️ best-effort | ⚠️ |

**LocalTile**(本地文件瓦片):
| prop | 类型 | 说明 |
|---|---|---|
| `pathTemplate` | string | 含 `{x}{y}{z}` 的本地文件路径 |
| `tileSize` | number | 瓦片像素 |
| `useAssets` | boolean | 从 app assets 读取(否则文件系统) |
| `zIndex` | number | 图层顺序 |

> codegen 全部用标量(string/number/boolean),无数组/对象,直接落地无需 JSON 序列化。

## 本期范围(MVP)与 best-effort 文档化

- **核心保证**:UrlTile 在线瓦片显示 + tileSize + minimumZ/maximumZ + flipY;LocalTile 文件系统瓦片显示。Android / iOS 双端。
- **best-effort(接 prop,尽力实现,差异写文档)**:`opacity`(Android 无原生 API)、`maximumNativeZ`、`doubleTileSize`、缓存三项(`tileCachePath`/`tileCacheMaxAge`/`offlineMode`)、iOS `zIndex`。
- `WMSTile`(M18)留待后续——它是 UrlTile 的 bbox 变体,JS 层算 URL 即可复用本通路。

## native 实现要点

- **Android UrlTile**:`object : UrlTileProvider(w, h) { getTileUrl(x,y,zoom) }`,在 `getTileUrl` 里:zoom 越界返回 null;`flipY` 时 `y = (1<<zoom)-1-y`;替换占位拼 URL → `URL(url)`。`TileOverlayOptions().tileProvider(p).zIndex(z).diskCacheEnabled(true).diskCacheDir(path)`。
- **Android LocalTile**:自定义 `TileProvider`,`getTile(x,y,zoom)` 按 `pathTemplate` 读文件(或 assets)字节 → `Tile(w, h, bytes)`;越界返回 `TileProvider.NO_TILE`。
- **iOS UrlTile**:`[[MATileOverlay alloc] initWithURLTemplate:tpl]`,设 `minimumZ/maximumZ/tileSize`;`addToMap` = `[map addOverlay:]`;`overlayRenderer` = `MATileOverlayRenderer`(设 `alpha=opacity`)。
- **iOS LocalTile**:`MATileOverlay` 子类重写 `loadTileAtPath:result:`,按 `pathTemplate` 读本地文件回传 `NSData`。

## 三层落点

- **JS**:新增 `UrlTileNativeComponent.ts` / `LocalTileNativeComponent.ts`;把 `MapUrlTile.tsx` / `MapLocalTile.tsx` 从 stub 改写为渲染对应 NativeComponent;`index.tsx` 导出不变(已导出)。
- **iOS**:`RNMapsUrlTile.{h,mm}` / `RNMapsLocalTile.{h,mm}`(实现 `RNMapsOverlayView`);`RCTComponentViewHelpers` 由 codegen 生成。父地图无需改。
- **Android**:`UrlTileView.kt` / `LocalTileView.kt` + `UrlTileManager.kt` / `LocalTileManager.kt`;`MapsPackage` 注册两个 manager;`MapView.addFeature/removeFeatureAt` 增加识别。
- **example**:新增演示页(对标 RNM `CustomTiles` / `CustomTilesLocal`),用公开 OSM 瓦片 `https://tile.openstreetmap.org/{z}/{x}/{y}.png` 演示 UrlTile。
- **测试**:JS 单测断言 `<UrlTile>` 渲染出 `RNMapsUrlTile` 且 props 透传;`flipY` 的 y 计算单测。

## 验收(同步回 RNM_PARITY_PLAN.md M11)

- [ ] UrlTile 在线瓦片显示
- [ ] LocalTile 本地瓦片显示
- [ ] `offlineMode` + 缓存路径 best-effort 生效
- [ ] Android / iOS 双端(iOS 待真机验证)
- [ ] 单测/快照
