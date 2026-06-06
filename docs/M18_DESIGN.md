# M18 设计:WMSTile

> 对应 [RNM_PARITY_PLAN.md](RNM_PARITY_PLAN.md) M18(P2)。WMSTile 是 UrlTile 的 **bbox 变体**:URL 模板用 `{minX}{minY}{maxX}{maxY}{width}{height}`(WMS GetMap),native 端按瓦片的 Web Mercator 范围拼 URL。**复用 M11 的 UrlTile 通路**,只加一个 `wms` 开关。

## 架构

- 不新增原生组件。给 `RNMapsUrlTile` 加一个 `wms` 布尔 prop;`wms=true` 时,native 的 tile provider 把瓦片 `x/y/z` 换算成 **EPSG:3857(Web Mercator)米制 bbox**,替换 `{minX}{minY}{maxX}{maxY}` 与 `{width}{height}`;`wms=false` 时仍走 `{x}{y}{z}`。
- `MapWMSTile.tsx` 从 stub 改为渲染 `RNMapsUrlTile` 原生组件并传 `wms=true`(`WMSTileProps` 本就 = `UrlTileProps`)。`MapUrlTile` 不传 `wms`(默认 false)。

## bbox 换算(native,EPSG:3857)

```
M = 20037508.342789244            // 半幅(米)
tiles = 2^zoom
tileMeters = (2M) / tiles
minX = -M + x * tileMeters
maxX = -M + (x+1) * tileMeters
maxY =  M - y * tileMeters
minY =  M - (y+1) * tileMeters
```
替换 `{minX}{minY}{maxX}{maxY}`,`{width}/{height}` 用 `tileSize`。

## 三层落点

- **JS**:`UrlTileNativeComponent.ts` 加 `wms?: boolean`;`MapUrlTile.tsx` 透传(默认 false);`MapWMSTile.tsx` 改为渲染 `NativeUrlTile`(`wms=true` + WMS props),保留 `__MAP_WMS_TILE` sentinel。
- **Android**:`UrlTileView.kt` 的 `getTileUrl` 加 `wms` 分支(bbox vs xyz);`UrlTileManager.kt` 加 `setWms`。
- **iOS**:`RNMapsUrlTile.mm` —— `wms=true` 时用一个重写 `URLForTilePath:` 的 `MATileOverlay` 子类(按 bbox 拼 URL);否则现有 `initWithURLTemplate:`。
- **example**:新增 "WMSTile (M18)" 开关(公开 WMS demo 服务)。
- **测试**:`MapWMSTile` sentinel + 渲染 `RNMapsUrlTile` 的断言(轻量)。

## 本期范围与 best-effort

- **核心保证**:WMS bbox 瓦片显示(EPSG:3857),Android 双端编译(iOS 待真机)。
- **best-effort / 文档化**:仅支持 Web Mercator(3857)bbox;EPSG:4326 等其他投影本期不做。缓存/`offlineMode` 等沿用 UrlTile 的 best-effort。

## 验收(同步回 RNM_PARITY_PLAN.md M18)

- [ ] 三层落地 + codegen/typecheck/lint/jest 通过
- [ ] WMS 图层显示(Android)
- [ ] Android 真机验证 / iOS 真机验证
