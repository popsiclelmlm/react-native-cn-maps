---
id: overlay
title: Overlay
sidebar_label: Overlay
description: Overlay 图片地面覆盖物组件的 props 与事件参考。
---

# Overlay

图片地面覆盖物——把一张图片贴合到地图的地理边界上。作为 `<MapView>` 的子节点渲染。也导出为 `MapOverlay`，动画版为 `OverlayAnimated`（或 `Overlay.Animated`）。

:::note 基础版
本页为 API 骨架，含完整 props 表；用法示例与厂商差异仍在补充中。
:::

```tsx
import MapView, { Overlay } from 'react-native-cn-maps';

<Overlay
  image={require('./floorplan.png')}
  bounds={[
    [31.22, 121.46], // 西南角 [lat, lng]
    [31.24, 121.48], // 东北角
  ]}
  bearing={30}
  opacity={0.8}
/>;
```

## props

| Prop | 类型 | 说明 |
|---|---|---|
| `image` | `ImageURISource \| ImageRequireSource \| string` | **必填**。覆盖物图片。 |
| `bounds` | `[Corner, Corner]` | **必填**。西南角与东北角，每个角为 `{latitude, longitude}` 或 `[lat, lng]` 元组。 |
| `bearing` | `number` | 旋转角度。 |
| `opacity` | `number` | 不透明度。 |
| `zIndex` | `number` | 层级。 |
| `tappable` | `boolean` | 是否可点击。 |

## 事件

| 事件 | `e.nativeEvent` | 说明 |
|---|---|---|
| `onPress` | `{ coordinate, position }` | 点击覆盖物（需 `tappable`）。 |
