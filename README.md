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

The library pins a known-good AMap SDK version. To override it from the host
Gradle project (e.g. to track a newer SDK):

```gradle
ext.amapSdkVersion = "11.2.000_loc11.2.000_sea9.8.0"
```

If you use `<Heatmap>`, enable Jetifier in the host app's `android/gradle.properties`
— AMap's heatmap component still references the legacy `android.support.v4`
(`LongSparseArray`), which throws `ClassNotFoundException` on AndroidX without it:

```properties
android.enableJetifier=true
```

### iOS

Set the AMap iOS key before the React Native surface starts:

```swift
import AMapFoundationKit

AMapServices.shared().apiKey = "YOUR_AMAP_IOS_KEY"
```

The podspec depends on `AMap3DMap`, which pulls in `AMapFoundation`.

#### Running on the iOS Simulator (Apple Silicon)

AMap's `MAMapKit` / `AMapFoundation` ship fat `.frameworks` that contain an
arm64 slice for **device** and an x86_64 slice for **simulator** only — there is
**no arm64 simulator slice**. On an Apple Silicon Mac the simulator app must
therefore be built as x86_64 (it runs under Rosetta). AMap's podspec already
excludes arm64 for the app target, but you must mirror that on every pod target,
otherwise the pods build arm64 and fail to link. Add this to your `Podfile`'s
`post_install`:

```ruby
post_install do |installer|
  # ... react_native_post_install(...) ...
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |bc|
      bc.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
    end
  end
end
```

Real-device (arm64) builds are unaffected — this is simulator-only.

## Privacy compliance (required)

China map SDKs (AMap, etc.) will not initialize until the host app declares
privacy compliance — until then the map renders **blank** (AMap logs errorCode
`555570`). Per PIPL and app-store review, you must show your privacy policy and
obtain the user's consent **before** initializing the map. This library never
auto-agrees on your behalf.

After the user accepts your privacy policy, call `setPrivacyConsent` **before
mounting any `<MapView>`**:

```tsx
import { setPrivacyConsent } from 'react-native-cn-maps';

// e.g. once, at app startup, after the user taps "Agree" in your dialog:
setPrivacyConsent({ agreed: true, contains: true, shown: true });
```

- `agreed` — the user agreed to the privacy policy
- `contains` — your privacy policy includes the map SDK's terms
- `shown` — the privacy policy was shown to the user

> Implemented on both Android and iOS. On iOS this maps to AMap's
> `+[MAMapView updatePrivacyShow:privacyInfo:]` / `+[MAMapView updatePrivacyAgree:]`.

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

## Features

`react-native-cn-maps` mirrors the `react-native-maps` API surface, so most code
ports over by changing the import. Verified on **both Android and iOS** (device +
simulator).

### Components

| Component | Notes |
|-----------|-------|
| `MapView` | `provider`, `coordinateSystem` (`gcj02` / `wgs84` / `bd09`), controlled `region` / `camera`, full prop & event surface |
| `Marker` | default / colored / `image` / custom React view (rasterized) / draggable |
| `Callout` | custom info-window bubbles |
| `Polyline` | gradient `strokeColors`, `lineCap` / `lineJoin` / `miterLimit`, tappable |
| `Polygon` | with `holes` |
| `Circle` | |
| `Overlay` | image ground overlay (`bounds` + `bearing` + `opacity`) |
| `UrlTile` / `LocalTile` / `WMSTile` | custom raster tile layers |
| `Heatmap` | weighted points + gradient |
| `Geojson` | pure-JS GeoJSON renderer (point / line / polygon, incl. holes) |

### MapView commands (ref API)

`animateToRegion`, `animateCamera` / `setCamera`, `getCamera`, `getMapBoundaries`,
`pointForCoordinate` / `coordinateForPoint`, `fitToCoordinates` / `fitToElements` /
`fitToSuppliedMarkers`, `takeSnapshot`, `setMapBoundaries`, `getMarkersFrames`.

See [docs/RNM_PARITY_PLAN.md](docs/RNM_PARITY_PLAN.md) for the full feature-by-feature
comparison with `react-native-maps`, and
[docs/MIGRATION_FROM_RN_MAPS.md](docs/MIGRATION_FROM_RN_MAPS.md) for migration notes.

### Not supported

- `provider="google"` — this library targets China providers
- Baidu / Tencent providers — planned (`coordinateSystem="bd09"` already wired in the JS layer)
- Web

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT
