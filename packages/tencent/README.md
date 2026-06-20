# react-native-cn-maps-tencent

Tencent (腾讯地图) provider for [`react-native-cn-maps`](https://github.com/popsiclelmlm/react-native-cn-maps).
Native coordinate system: **GCJ-02**.

## Install

```sh
yarn add react-native-cn-maps react-native-cn-maps-tencent
```

Then select it: `<MapView provider="tencent" />`.

## Native key setup

Get a Tencent Map key from the [Tencent LBS console](https://lbs.qq.com/).

### iOS

Add the `QMapKit` pod (the podspec already depends on it) and set the key + privacy
agreement in `AppDelegate`:

```objc
[[QMapServices sharedServices] setPrivacyAgreement:YES];
[QMapServices sharedServices].APIKey = @"<YOUR_IOS_TENCENT_KEY>";
```

### Android

Declare the key (and agree to privacy) per the Tencent SDK docs — typically via a
manifest `<meta-data>` and `TencentMapInitializer.setAgreePrivacy(true)`, which the
library calls through `setPrivacyConsent()`.

## Status & known gaps

> ⚠️ This adapter is written against the Tencent Map SDK API but **not yet compiled**
> (the example app doesn't bundle the Tencent SDK). Once you add the SDK and key,
> build it and resolve the `// VERIFY:` comments in the adapter sources
> (`ios/CNTencentMapAdapter.mm`, `android/.../TencentMapAdapter.kt`) — especially the
> Maven artifact coordinates, privacy entry point, snapshot, and callback names.

Current gaps (not-yet-wired):

- **Heatmap** and **URL/local tile overlays** are not wired (Tencent-specific
  classes) — TODO.
- Marker coordinate animation is a direct set (no built-in tween wired).

Pin the SDK version and override `ext.tencentSdkVersion` if needed.
