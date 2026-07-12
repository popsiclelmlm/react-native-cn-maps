---
id: url-tile
title: UrlTile
sidebar_label: UrlTile
description: UrlTile 在线栅格瓦片图层组件的 props 参考。
---

# UrlTile

在线 URL 栅格瓦片图层（自定义底图 / 叠加图层）。作为 `<MapView>` 的子节点渲染。也导出为 `MapUrlTile`。

:::note 基础版
本页为 API 骨架，含完整 props 表；用法示例与厂商差异仍在补充中。瓦片图层目前仅高德接通（百度/腾讯 TODO），见[支持矩阵](../guides/provider-matrix.md)。
:::

```tsx
import MapView, { UrlTile } from 'react-native-cn-maps';

<UrlTile
  urlTemplate="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
  maximumZ={19}
  flipY={false}
/>;
```

## props

| Prop | 类型 | 说明 |
|---|---|---|
| `urlTemplate` | `string` | **必填**。瓦片 URL 模板，含 `{x}` / `{y}` / `{z}` 占位。 |
| `minimumZ` / `maximumZ` | `number` | 瓦片可见的缩放级别范围。 |
| `maximumNativeZ` | `number` | 服务端可用的最大缩放级别。 |
| `tileSize` | `number` | 瓦片像素尺寸。 |
| `doubleTileSize` | `boolean` | 双倍瓦片尺寸（高清）。 |
| `flipY` | `boolean` | 翻转 Y 轴（TMS 方案）。 |
| `opacity` | `number` | 不透明度。 |
| `shouldReplaceMapContent` | `boolean` | 是否替换底图内容。 |
| `tileCachePath` | `string` | 本地缓存目录。 |
| `tileCacheMaxAge` | `number` | 缓存有效期（秒）。 |
| `offlineMode` | `boolean` | 离线模式（仅用缓存）。 |
| `zIndex` | `number` | 层级。 |

## 相关

- WMS 服务用 [WMSTile](./wms-tile.md)；本地瓦片用 [LocalTile](./local-tile.md)。
