# react-native-cn-maps-amap

AMap (高德地图) provider for [`react-native-cn-maps`](https://github.com/popsiclelmlm/react-native-cn-maps).
Native coordinate system: **GCJ-02**.

## Install

```sh
yarn add react-native-cn-maps react-native-cn-maps-amap
```

Then select it: `<MapView provider="amap" />` (amap is also the default).

## Native key setup

Get an AMap API key from the [AMap console](https://lbs.amap.com/).

### iOS

In `AppDelegate`, set the key before any map mounts (the example reads it from an
`AMapApiKey` Info.plist entry):

```swift
import AMapFoundationKit
AMapServices.shared().apiKey = "<YOUR_IOS_AMAP_KEY>"
```

Run `pod install`. On Apple-Silicon simulators the AMap frameworks have no arm64
simulator slice — exclude it in your Podfile `post_install`
(`EXCLUDED_ARCHS[sdk=iphonesimulator*] = 'arm64'` on every pod target).

### Android

Declare the key in `AndroidManifest.xml`:

```xml
<meta-data android:name="com.amap.api.v2.apikey" android:value="<YOUR_ANDROID_AMAP_KEY>" />
```

## Privacy

AMap refuses to initialize until privacy compliance is declared. Call
`setPrivacyConsent({ agreed, contains, shown })` from `react-native-cn-maps` after
the user accepts your privacy policy, **before** mounting `<MapView>`.

## Status

This provider is implemented and build-verified (iOS + Android) against the AMap
3D Map SDK. It is the reference adapter for the project.
