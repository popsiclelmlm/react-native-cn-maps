---
id: quick-start
title: 快速开始
sidebar_label: 快速开始
sidebar_position: 2
description: 用 react-native-cn-maps 跑通第一张地图：声明隐私合规、渲染 MapView、加标记、监听事件。
---

# 快速开始

本页假设你已经[装好依赖](./installation.md)并[配好厂商 SDK key](../native-setup/amap.md)。下面从零跑通一张能交互的地图。

## 1. 声明隐私合规（必做）

中国地图 SDK 在宿主应用声明隐私合规之前**不会初始化，地图渲染为空白**。在挂载任何 `<MapView>` 之前，调用一次 `setPrivacyConsent`：

```tsx title="App.tsx"
import { setPrivacyConsent } from 'react-native-cn-maps';

// 应用启动时调用一次（务必在用户点击你自己的隐私弹窗"同意"之后）：
setPrivacyConsent({ agreed: true, contains: true, shown: true });
```

:::danger 本库绝不代为同意
依照 PIPL 与应用商店审核要求，隐私政策的展示与取得同意由**你的应用**负责。上面这行只是把用户已作出的同意转达给地图 SDK。完整背景见[隐私合规](../guides/privacy-compliance.md)。
:::

## 2. 渲染一张地图

```tsx title="MapScreen.tsx"
import MapView, { Marker } from 'react-native-cn-maps';

export default function MapScreen() {
  return (
    <MapView
      provider="amap"
      coordinateSystem="gcj02"
      style={{ flex: 1 }}
      initialRegion={{
        latitude: 31.2304,
        longitude: 121.4737,
        latitudeDelta: 0.05,
        longitudeDelta: 0.05,
      }}
    >
      <Marker
        coordinate={{ latitude: 31.2304, longitude: 121.4737 }}
        title="上海"
        description="外滩附近"
      />
    </MapView>
  );
}
```

几个要点：

- `style={{ flex: 1 }}`：MapView 需要一个有明确尺寸的容器，否则不可见。
- `provider="amap"`：选择地图厂商，默认就是 `amap`。切换厂商见[选择地图厂商](./choosing-provider.md)。
- `coordinateSystem="gcj02"`：声明**你传入的坐标**属于哪个坐标系，库会自动转换到厂商原生系。若你的数据来自 GPS（如 `expo-location`），应填 `wgs84`。见[坐标系专题](../guides/coordinate-systems.md)。
- `initialRegion` vs `region`：`initialRegion` 只在首次挂载生效（非受控）；要受控地图用 `region` + `onRegionChangeComplete`。

## 3. 监听地图事件

```tsx
<MapView
  provider="amap"
  style={{ flex: 1 }}
  initialRegion={/* ... */}
  onPress={(e) => {
    // coordinate 已转换回你声明的 coordinateSystem
    console.log('点了地图', e.nativeEvent.coordinate);
  }}
  onRegionChangeComplete={(e) => {
    // 本库的事件回调统一是「事件信封」：从 e.nativeEvent 取值
    console.log('视野变化', e.nativeEvent.region, '手势触发：', e.nativeEvent.isGesture);
  }}
>
  <Marker
    coordinate={{ latitude: 31.2304, longitude: 121.4737 }}
    onPress={(e) => console.log('点了标记', e.nativeEvent.identifier)}
  />
</MapView>
```

## 4. 命令式控制相机

通过 ref 调用命令，例如平滑移动到某个区域：

```tsx
import { useRef } from 'react';
import MapView, { type MapViewHandle } from 'react-native-cn-maps';

function Controlled() {
  const mapRef = useRef<MapViewHandle>(null);

  return (
    <>
      <MapView ref={mapRef} provider="amap" style={{ flex: 1 }} initialRegion={/* ... */} />
      <Button
        title="飞到北京"
        onPress={() =>
          mapRef.current?.animateToRegion(
            {
              latitude: 39.9042,
              longitude: 116.4074,
              latitudeDelta: 0.05,
              longitudeDelta: 0.05,
            },
            800
          )
        }
      />
    </>
  );
}
```

`animateCamera`、`fitToCoordinates`、`getCamera`、`takeSnapshot` 等完整方法见 [MapView API](../api/map-view.md#方法ref)。

## 常见坑

| 现象 | 原因 | 处理 |
|---|---|---|
| 地图一片空白 | 没调 `setPrivacyConsent`，或没配 SDK key | 见[隐私合规](../guides/privacy-compliance.md) / [原生配置](../native-setup/amap.md) |
| 看不到地图容器 | MapView 没有尺寸 | 给 `style` 明确宽高或 `flex: 1` |
| 标记 / 视野整体偏移 | 坐标系填错 | 见[坐标系专题](../guides/coordinate-systems.md) |
| 切换 provider 无效 | provider 挂载后固定 | 给 MapView 设 `key={provider}` 强制重挂 |

下一步：了解[如何选择地图厂商](./choosing-provider.md)，或直接查 [API 参考](../api/index.md)。
