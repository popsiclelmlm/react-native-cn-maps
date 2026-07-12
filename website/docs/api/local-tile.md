---
id: local-tile
title: LocalTile
sidebar_label: LocalTile
description: LocalTile 本地栅格瓦片图层组件的 props 参考。
---

# LocalTile

本地栅格瓦片图层——从设备文件系统或打包资源读取瓦片。作为 `<MapView>` 的子节点渲染。也导出为 `MapLocalTile`。

:::note 基础版
本页为 API 骨架，含完整 props 表；用法示例与厂商差异仍在补充中。瓦片图层目前仅高德接通，见[支持矩阵](../guides/provider-matrix.md)。
:::

```tsx
import MapView, { LocalTile } from 'react-native-cn-maps';

<LocalTile
  pathTemplate="/data/tiles/{z}/{x}/{y}.png"
  tileSize={256}
/>;
```

## props

| Prop | 类型 | 说明 |
|---|---|---|
| `pathTemplate` | `string` | **必填**。本地瓦片路径模板，含 `{x}` / `{y}` / `{z}` 占位。 |
| `tileSize` | `number` | 瓦片像素尺寸。 |
| `useAssets` | `boolean` | 从打包资源（assets）而非文件系统读取。 |
| `zIndex` | `number` | 层级。 |
