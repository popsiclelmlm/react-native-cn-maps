---
id: callout
title: Callout
sidebar_label: Callout
description: Callout 自定义信息气泡组件的 props 与事件参考。
---

# Callout

自定义信息气泡，作为 [`<Marker>`](./marker.md) 的子节点渲染。点击标记时弹出。也导出为 `MapCallout`。

:::note 基础版
本页为 API 骨架，含完整 props 表；用法示例与厂商差异仍在补充中。
:::

```tsx
import MapView, { Marker, Callout } from 'react-native-cn-maps';

<Marker coordinate={{ latitude: 31.23, longitude: 121.47 }}>
  <Callout onPress={() => console.log('点了气泡')}>
    <View>
      <Text>自定义气泡内容</Text>
    </View>
  </Callout>
</Marker>;
```

## props

继承 `ViewProps`，另有：

| Prop | 类型 | 说明 |
|---|---|---|
| `tooltip` | `boolean` | `true` 时只渲染你的内容、不套系统气泡外框。 |
| `alphaHitTest` | `boolean` | 按像素透明度命中测试。 |
| `children` | `ReactNode` | 气泡内容。 |

## 事件

| 事件 | `e.nativeEvent` | 说明 |
|---|---|---|
| `onPress` | `{ identifier?, point?, frame? }` | 点击气泡。 |

## 相关

- 气泡内需独立响应点击的子区域用 [CalloutSubview](./callout-subview.md)。
