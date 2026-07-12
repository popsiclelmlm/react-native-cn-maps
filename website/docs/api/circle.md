---
id: circle
title: Circle
sidebar_label: Circle
description: Circle 圆形覆盖物组件的 props 与事件参考。
---

# Circle

圆形覆盖物。作为 `<MapView>` 的子节点渲染。也导出为 `MapCircle`。

:::note 基础版
本页为 API 骨架，含完整 props 表；用法示例与厂商差异仍在补充中。
:::

```tsx
import MapView, { Circle } from 'react-native-cn-maps';

<Circle
  center={{ latitude: 31.2304, longitude: 121.4737 }}
  radius={500}
  strokeColor="#1f6feb"
  fillColor="rgba(31,111,235,0.2)"
  strokeWidth={2}
/>;
```

## props

| Prop | 类型 | 说明 |
|---|---|---|
| `center` | `LatLng` | **必填**。圆心。 |
| `radius` | `number` | **必填**。半径（米）。 |
| `strokeColor` | `ColorValue` | 描边颜色。 |
| `strokeWidth` | `number` | 线宽。 |
| `fillColor` | `ColorValue` | 填充色。 |
| `lineDashPattern` | `number[]` | 虚线段长模式。 |
| `lineDashPhase` | `number` | 虚线相位。 |
| `lineCap` | `'butt' \| 'round' \| 'square'` | 线端样式。 |
| `lineJoin` | `'miter' \| 'round' \| 'bevel'` | 拐角样式。 |
| `miterLimit` | `number` | 斜接限制。 |
| `zIndex` | `number` | 层级。 |
| `tappable` | `boolean` | 是否可点击。 |

## 事件

| 事件 | `e.nativeEvent` | 说明 |
|---|---|---|
| `onPress` | `{ coordinate, position }` | 点击圆（需 `tappable`）。 |
