# react-native-cn-maps

React Native Map components for China providers, with a `react-native-maps`-compatible API shape and a Fabric-only native implementation.

## Installation

```sh
npm install react-native-cn-maps
```

This package currently targets React Native New Architecture/Fabric only. The first provider is AMap/Gaode (`provider="amap"`) on Android and iOS.

## Native Setup

### Android

Add your AMap Android key in the host app manifest:

```xml
<application>
  <meta-data
    android:name="com.amap.api.v2.apikey"
    android:value="YOUR_AMAP_ANDROID_KEY" />
</application>
```

The Android SDK version can be overridden from the host Gradle project:

```gradle
ext.amapSdkVersion = "latest.integration"
```

### iOS

Set the AMap iOS key before the React Native surface starts:

```swift
import AMapFoundationKit

AMapServices.shared().apiKey = "YOUR_AMAP_IOS_KEY"
```

The podspec depends on `AMap3DMap`, which pulls in `AMapFoundation`.

## Usage

```tsx
import MapView, { Marker } from 'react-native-cn-maps';

<MapView
  provider="amap"
  coordinateSystem="gcj02"
  initialRegion={{
    latitude: 31.2304,
    longitude: 121.4737,
    latitudeDelta: 0.05,
    longitudeDelta: 0.05,
  }}
>
  <Marker
    coordinate={{ latitude: 31.2304, longitude: 121.4737 }}
    title="Shanghai"
  />
</MapView>;
```

## MVP Scope

- `MapView`
- `Marker`
- `initialRegion`
- controlled `region`
- `onRegionChange`
- `onRegionChangeComplete`
- marker `onPress`
- `animateToRegion`
- `coordinateSystem="gcj02" | "wgs84"`

`Polyline`, `Polygon`, `Circle`, custom marker views, callouts, and extra providers are intentionally left for later milestones.

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT
