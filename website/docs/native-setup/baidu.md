---
id: baidu
title: 百度 Baidu 原生配置
sidebar_label: 百度 Baidu
description: 配置百度地图的 iOS / Android AK，了解百度适配器的已知缺口。
---

# 百度 Baidu 原生配置

原生坐标系 **BD-09**（`provider="baidu"` 时库自动把你的坐标转换为 BD-09）。

先申请 AK：[百度地图开放平台控制台](https://lbsyun.baidu.com/)。

:::warning 适配器状态
百度适配器已按百度 Map SDK 的 API 编写，但**尚未编译验证**（示例 App 未打包百度 SDK）。接入 SDK 与 key 后请自行构建，并处理适配器源码中的 `// VERIFY:` 注释（`ios/CNBaiduMapAdapter.mm`、`android/.../BaiduMapAdapter.kt`）。见下方[已知缺口](#已知缺口)。
:::

## Android

在 `AndroidManifest.xml` 中声明 AK：

```xml title="android/app/src/main/AndroidManifest.xml"
<meta-data
  android:name="com.baidu.lbsapi.API_KEY"
  android:value="YOUR_ANDROID_BAIDU_AK" />
```

隐私合规由 `react-native-cn-maps` 的 `setPrivacyConsent()` 处理，它会调用
`SDKInitializer.setAgreePrivacy(...)` + `SDKInitializer.initialize(...)`。

## iOS

添加 `BaiduMapKit` pod（podspec 已声明依赖），在 `AppDelegate` 中声明隐私同意并用你的 key 启动 SDK：

```objc title="ios/AppDelegate.mm"
[BMKMapManager setAgreePrivacy:YES];
BMKMapManager *manager = [[BMKMapManager alloc] init];
[manager start:@"YOUR_IOS_BAIDU_AK" generalDelegate:nil];
```

如需固定或覆盖 SDK 版本，在 `Podfile.lock` / gradle 中锁定，或覆盖 `ext.baiduSdkVersion`。

## 隐私合规

调用 `setPrivacyConsent({ agreed, contains, shown })`，详见[隐私合规](../guides/privacy-compliance.md)。

## 已知缺口

以下为百度 SDK 限制或尚未接通的能力：

- **Heatmap** 与 **URL/本地瓦片覆盖物**未接通（百度用专用类，不走标准 overlay 路径）——TODO。
- **Polygon 孔洞（holes）** 百度 polygon API 不支持（孔洞会被丢弃）。
- 无原生夜间底图（需自定义样式文件）；标记坐标动画为直接设置（无内置补间）。

完整平台 × 能力对照见[厂商支持矩阵](../guides/provider-matrix.md)。
