---
id: index
title: API 参考
sidebar_label: 概览
slug: /api
description: react-native-cn-maps 全部 13 个组件、方法与类型的 API 参考总览。
---

# API 参考

`react-native-cn-maps` 从 `react-native-maps` 平移了 13 个组件。下表是入口，每个组件一页，含 props / 事件 / 方法表格。

:::info 事实来源
每页的 props / 事件 / 类型以核心包 `packages/core/src/types.ts` 与组件源码为准。发现文档与源码不一致，以源码为准并欢迎[反馈](https://github.com/popsiclelmlm/react-native-cn-maps/issues)。
:::

## 组件

| 组件 | 说明 |
|---|---|
| [`MapView`](./map-view.md) | 地图容器：`provider`、`coordinateSystem`、受控 `region` / `camera`、完整属性事件与 ref 方法 |
| [`Marker`](./marker.md) | 标记：默认 / 自定义颜色 / `image` / 自定义 React 视图 / 可拖拽 |
| [`Callout`](./callout.md) | 自定义信息气泡 |
| [`CalloutSubview`](./callout-subview.md) | 气泡内可独立响应点击的子视图 |
| [`Polyline`](./polyline.md) | 折线：渐变 `strokeColors`、`lineCap` / `lineJoin`、可点击 |
| [`Polygon`](./polygon.md) | 多边形：支持 `holes` 孔洞 |
| [`Circle`](./circle.md) | 圆：圆心 / 半径 / 描边 / 填充 |
| [`Overlay`](./overlay.md) | 图片地面覆盖物（`bounds` + `bearing` + `opacity`） |
| [`UrlTile`](./url-tile.md) | 在线 URL 栅格瓦片图层 |
| [`WMSTile`](./wms-tile.md) | WMS 栅格瓦片图层 |
| [`LocalTile`](./local-tile.md) | 本地栅格瓦片图层 |
| [`Heatmap`](./heatmap.md) | 权重点 + 渐变热力图 |
| [`Geojson`](./geojson.md) | 纯 JS 的 GeoJSON 渲染（点 / 线 / 面，含孔洞） |

## 命名与别名

多数组件同时以「短名」和「`Map` 前缀名」导出（如 `Marker` = `MapMarker`），并提供 `Animated` 包装：

```tsx
import MapView, {
  Marker,        // = MapMarker
  Polyline,      // = MapPolyline
  MarkerAnimated,
  Animated,      // = Animated 包装的 MapView
} from 'react-native-cn-maps';
```

从 rn-maps 迁移的类型别名（`Provider`、`ChangeEvent`、`FitToOptions` 等）见[迁移指南](../guides/migrate-from-react-native-maps.md#类型别名少改代码)。

## 通用约定

- **坐标系**：所有接受 `LatLng` 的 props / 事件都遵循 `<MapView coordinateSystem>` 声明的系，库自动转换。见[坐标系专题](../guides/coordinate-systems.md)。
- **事件信封**：所有事件回调形如 `(e) => void`，数据在 `e.nativeEvent`。
- **覆盖物作为子节点**：`<Marker>`、`<Polyline>` 等作为 `<MapView>` 的 children 渲染。
