---
id: tencent
title: 腾讯 Tencent 原生配置
sidebar_label: 腾讯 Tencent
description: 配置腾讯地图的 iOS / Android key，了解腾讯适配器的已知缺口。
---

# 腾讯 Tencent 原生配置

原生坐标系 **GCJ-02**。

先申请 key：[腾讯位置服务控制台](https://lbs.qq.com/)。

:::warning 适配器状态
腾讯适配器已按腾讯 Map SDK 的 API 编写，但**尚未编译验证**（示例 App 未打包腾讯 SDK）。接入 SDK 与 key 后请自行构建，并处理适配器源码中的 `// VERIFY:` 注释（`ios/CNTencentMapAdapter.mm`、`android/.../TencentMapAdapter.kt`）——尤其是 Maven 依赖坐标、隐私入口、快照与回调命名。见下方[已知缺口](#已知缺口)。
:::

## Android

按腾讯 SDK 文档声明 key 并同意隐私——通常通过 manifest `<meta-data>` 与
`TencentMapInitializer.setAgreePrivacy(true)`，后者由本库的 `setPrivacyConsent()` 调用。

## iOS

添加 `QMapKit` pod（podspec 已声明依赖），在 `AppDelegate` 中设置 key 与隐私同意：

```objc title="ios/AppDelegate.mm"
[[QMapServices sharedServices] setPrivacyAgreement:YES];
[QMapServices sharedServices].APIKey = @"YOUR_IOS_TENCENT_KEY";
```

如需固定或覆盖 SDK 版本，锁定版本或覆盖 `ext.tencentSdkVersion`。

## 隐私合规

调用 `setPrivacyConsent({ agreed, contains, shown })`，详见[隐私合规](../guides/privacy-compliance.md)。

## 已知缺口

以下能力尚未接通：

- **Heatmap** 与 **URL/本地瓦片覆盖物**未接通（腾讯专用类）——TODO。
- 标记坐标动画为直接设置（无内置补间）。

完整平台 × 能力对照见[厂商支持矩阵](../guides/provider-matrix.md)。
