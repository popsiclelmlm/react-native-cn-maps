# react-native-cn-maps-baidu

Baidu (百度地图) provider for [`react-native-cn-maps`](https://github.com/popsiclelmlm/react-native-cn-maps).
Native coordinate system: **BD-09** (the library converts your coordinates to BD-09
automatically when `provider="baidu"`).

## Install

```sh
yarn add react-native-cn-maps react-native-cn-maps-baidu
```

Then select it: `<MapView provider="baidu" />`.

## Native key setup

Get a Baidu Map AK from the [Baidu Maps console](https://lbsyun.baidu.com/).

### iOS

Add the `BaiduMapKit` pod (the podspec already depends on it) and start the SDK with
your key in `AppDelegate`, after declaring privacy agreement:

```objc
[BMKMapManager setAgreePrivacy:YES];
BMKMapManager *manager = [[BMKMapManager alloc] init];
[manager start:@"<YOUR_IOS_BAIDU_AK>" generalDelegate:nil];
```

### Android

Declare the AK in `AndroidManifest.xml`:

```xml
<meta-data android:name="com.baidu.lbsapi.API_KEY" android:value="<YOUR_ANDROID_BAIDU_AK>" />
```

Privacy is handled via `setPrivacyConsent()` from `react-native-cn-maps`, which calls
`SDKInitializer.setAgreePrivacy(...)` + `SDKInitializer.initialize(...)`.

## Status & known gaps

> ⚠️ This adapter is written against the Baidu Map SDK API but **not yet compiled**
> (the project's example app doesn't bundle the Baidu SDK). Once you add the SDK and
> key, build it and resolve the `// VERIFY:` comments in the adapter sources
> (`ios/CNBaiduMapAdapter.mm`, `android/.../BaiduMapAdapter.kt`).

Current gaps (Baidu SDK limitations or not-yet-wired):

- **Heatmap** and **URL/local tile overlays** are not wired (Baidu uses dedicated
  classes, not the standard overlay path) — TODO.
- **Polygon holes** are unsupported by Baidu's polygon API (holes are dropped).
- No native night basemap (needs a custom style file); marker coordinate animation
  is a direct set (no built-in tween).

Pin the SDK version in your app's `Podfile.lock` / gradle and override
`ext.baiduSdkVersion` if needed.
