---
id: wms-tile
title: WMSTile
sidebar_label: WMSTile
description: WMSTile WMS 栅格瓦片图层组件的 props 参考。
---

# WMSTile

WMS（Web Map Service）栅格瓦片图层。props 与 [`UrlTile`](./url-tile.md) 相同，专用于 WMS 服务的 URL 模板。也导出为 `MapWMSTile`。

:::note 基础版
本页为 API 骨架，含完整 props 表；用法示例与厂商差异仍在补充中。瓦片图层目前仅高德接通，见[支持矩阵](../guides/provider-matrix.md)。
:::

```tsx
import MapView, { WMSTile } from 'react-native-cn-maps';

<WMSTile
  urlTemplate="https://example.com/wms?service=WMS&version=1.1.0&request=GetMap&layers=layer&bbox={minX},{minY},{maxX},{maxY}&width=256&height=256&srs=EPSG:3857&format=image/png"
  maximumZ={19}
/>;
```

## props

与 [`UrlTile`](./url-tile.md#props) 完全一致：`urlTemplate`、`minimumZ` / `maximumZ`、`maximumNativeZ`、`tileSize`、`doubleTileSize`、`flipY`、`opacity`、`shouldReplaceMapContent`、`tileCachePath`、`tileCacheMaxAge`、`offlineMode`、`zIndex`。

`urlTemplate` 使用 WMS 的 `{minX}` / `{minY}` / `{maxX}` / `{maxY}` 等 bbox 占位。
