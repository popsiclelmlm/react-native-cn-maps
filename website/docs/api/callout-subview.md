---
id: callout-subview
title: CalloutSubview
sidebar_label: CalloutSubview
description: CalloutSubview 组件的 props 与事件参考。
---

# CalloutSubview

[`<Callout>`](./callout.md) 内部可**独立响应点击**的子视图——让气泡里的按钮各自触发，而非整个气泡一个点击。也导出为 `MapCalloutSubview`。

:::note 基础版
本页为 API 骨架，含完整 props 表；用法示例与厂商差异仍在补充中。
:::

```tsx
import { Marker, Callout, CalloutSubview } from 'react-native-cn-maps';

<Marker coordinate={coord}>
  <Callout>
    <View>
      <Text>标题</Text>
      <CalloutSubview onPress={() => console.log('点了按钮')}>
        <Text>详情</Text>
      </CalloutSubview>
    </View>
  </Callout>
</Marker>;
```

## props

继承 `ViewProps`，另有：

| Prop | 类型 | 说明 |
|---|---|---|
| `onPress` | `(e) => void` | 点击该子视图，`e.nativeEvent` 含 `identifier?` / `point?` / `frame?`。 |
| `children` | `ReactNode` | 子视图内容。 |
