---
id: amap
title: 高德 AMap 原生配置
sidebar_label: 高德 AMap
description: 配置高德地图的 iOS / Android SDK key、Apple Silicon 模拟器排除 arm64、以及 Heatmap 的 Jetifier 处理。
---

# 高德 AMap 原生配置

高德是本库的默认厂商，也是参考适配器（iOS + Android 均已构建验证）。原生坐标系 **GCJ-02**。

先申请 key：[高德开放平台控制台](https://lbs.amap.com/)（iOS 与 Android 需要各自的 key）。

## Android

在宿主应用的 `AndroidManifest.xml` 中声明高德 Android key：

```xml title="android/app/src/main/AndroidManifest.xml"
<application>
  <meta-data
    android:name="com.amap.api.v2.apikey"
    android:value="YOUR_AMAP_ANDROID_KEY" />
</application>
```

Android 通过 autolinking 接入，通常无需其他改动。

### SDK 版本覆盖

库固定了一个已验证的高德 SDK 版本。如需更新版本，在宿主 Gradle 工程覆盖：

```groovy title="android/build.gradle"
ext {
  amapSdkVersion = "11.2.000_loc11.2.000_sea9.8.0"
}
```

### &lt;Heatmap&gt; 的 Jetifier

如果使用 [`<Heatmap>`](../api/heatmap.md)，需在 `android/gradle.properties` 开启 Jetifier——高德热力图组件仍引用旧版 `android.support.v4`（`LongSparseArray`），AndroidX 下否则抛 `ClassNotFoundException`：

```properties title="android/gradle.properties"
android.enableJetifier=true
```

## iOS

在 React Native 界面启动前设置高德 iOS key（如在 `AppDelegate` 中）：

```swift title="ios/AppDelegate.swift"
import AMapFoundationKit

AMapServices.shared().apiKey = "YOUR_AMAP_IOS_KEY"
```

podspec 已依赖 `AMap3DMap`（自动带上 `AMapFoundation`），执行 `pod install` 即可：

```sh
cd ios && pod install
```

### Apple Silicon 上运行模拟器

高德 `MAMapKit` / `AMapFoundation` 的 fat framework 只有**真机 arm64** 和**模拟器 x86_64** 两个切片，没有 arm64 模拟器切片。Apple Silicon 上模拟器构建必须走 x86_64（Rosetta 运行）。需对所有 pod target 排除 arm64，在 `Podfile` 的 `post_install` 中添加：

```ruby title="ios/Podfile"
post_install do |installer|
  # ... react_native_post_install(...) ...
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |bc|
      bc.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
    end
  end
end
```

真机（arm64）构建不受影响，此处理仅针对模拟器。

## 隐私合规

高德在声明隐私合规前不会初始化，地图渲染为空白（日志输出 `555570`）。用户同意你的隐私政策后，在挂载 `<MapView>` **之前**调用：

```tsx
import { setPrivacyConsent } from 'react-native-cn-maps';

setPrivacyConsent({ agreed: true, contains: true, shown: true });
```

详见[隐私合规](../guides/privacy-compliance.md)。

## 状态

高德适配器已针对 AMap 3D Map SDK 实现并在 iOS + Android 上构建验证，是本项目的参考适配器。
