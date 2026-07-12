---
id: choosing-provider
title: 选择地图厂商
sidebar_label: 选择地图厂商
sidebar_position: 3
description: 通过 provider 属性在高德、百度、腾讯、华为地图之间选择，理解各厂商的原生坐标系与平台支持。
---

# 选择地图厂商

## provider 属性

用 `provider` 属性选择底层地图 SDK，默认 `amap`：

```tsx
<MapView provider="amap" />   {/* 或 "baidu" / "tencent" / "mapkit" */}
```

| `provider` | 适配器包 | 原生坐标系 | 平台 |
|---|---|---|---|
| `amap`（默认） | `react-native-cn-maps-amap` | GCJ-02 | iOS · Android · HarmonyOS |
| `baidu` | `react-native-cn-maps-baidu` | BD-09 | iOS¹ · Android · HarmonyOS |
| `tencent` | `react-native-cn-maps-tencent` | GCJ-02 | iOS¹ · Android · HarmonyOS |
| `mapkit` | `react-native-cn-maps-mapkit` | GCJ-02 | 仅 HarmonyOS |

<sub>¹ 百度 / 腾讯 iOS 适配器随包发布但尚未真机验证，默认关闭 iOS autolinking。详见[厂商支持矩阵](../guides/provider-matrix.md)。</sub>

## 两条规则

1. **`provider` 挂载后固定**。切换厂商需要重挂 `<MapView>`——给它设 `key={provider}` 即可：

   ```tsx
   <MapView key={provider} provider={provider} />
   ```

2. **必须装对应的适配器包**。`provider="baidu"` 需要 `react-native-cn-maps-baidu`，并在原生侧配好百度的 key。见[安装](./installation.md)与各厂商[原生配置](../native-setup/baidu.md)。

## 该选哪个？

- **没有特别偏好** → `amap`（高德）。文档最全、三端支持最成熟、本库的默认厂商。
- **已有某厂商的 key / 账号体系** → 选对应厂商，省去重新申请。
- **HarmonyOS Next 且想用系统地图** → `mapkit`（华为 Map Kit），无需下载 SDK、走 AGC 鉴权。见 [Map Kit 配置](../native-setup/mapkit.md)。
- **数据是 BD-09 坐标** → 用 `baidu` 可省一次转换（但本库任意厂商都会自动转换，不必为此妥协）。

## 坐标系会自动处理

不同厂商原生坐标系不同（高德/腾讯 GCJ-02、百度 BD-09），但你**不需要**为切换厂商而改坐标数据——只要如实声明 `coordinateSystem`（你传入坐标的系），库会自动转换到目标厂商的原生系。详见[坐标系专题](../guides/coordinate-systems.md)。

```tsx
// 同一份 wgs84 数据，切厂商时坐标不用动
<MapView provider={provider} coordinateSystem="wgs84" /* ... */ />
```
