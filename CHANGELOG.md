# Changelog

## 0.3.0

Multi-provider release — the library is now a **provider-agnostic core + per-vendor
adapter packages**, with a runtime `provider` switch and experimental HarmonyOS support.

### Added

- **Monorepo split** — `react-native-cn-maps` (core, no map SDK) plus opt-in
  adapter packages `react-native-cn-maps-amap` / `-baidu` / `-tencent`. Install
  only the providers you use.
- **Runtime provider selection** — `<MapView provider="amap" | "baidu" | "tencent" />`,
  fixed at mount. Coordinate conversion is now provider-aware (AMap/Tencent →
  GCJ-02, Baidu → BD-09), still routed through GCJ-02 in JS.
- **Baidu (百度地图) & Tencent (腾讯地图) providers** — verified rendering +
  authenticating on **Android**. iOS adapter source ships in each package with a
  pinned pod (`BaiduMapKit ~> 6.6.0` / `QMapKit ~> 5.6.0`) but is **not yet
  device-verified**, so iOS autolinking is disabled by default for these two.
- **HarmonyOS Next (鸿蒙, via RNOH)** — *experimental / in progress*. ArkTS source
  for all three providers under each package's `harmony/`; example runs on the
  emulator with an AMap placeholder. Not device-verified. See
  [migration/harmony/06-integration-and-status.md](migration/harmony/06-integration-and-status.md).
- **`addressForCoordinate`** reverse geocoding (AMap, iOS + Android).
- **`kmlSrc`** — parse KML to GeoJSON and render via `<Geojson>`, fires `onKmlReady`.
- **react-native-maps migration guide** + parity matrix
  ([docs/MIGRATION_FROM_RN_MAPS.md](docs/MIGRATION_FROM_RN_MAPS.md)) — most projects
  migrate by changing the import.

### Notes

- **Provider support matrix:** AMap = iOS + Android (full); Baidu / Tencent =
  Android verified, iOS experimental (autolink off by default); HarmonyOS =
  experimental on all three, not device-verified.
- `provider` is fixed at mount — change it by remounting `<MapView>` (e.g.
  `key={provider}`).

## 0.2.0

First feature-complete, dual-platform release — **iOS and Android at parity**,
verified on device + simulator.

### Added

- **iOS support** (AMap / MAMapKit), full parity with Android.
- Components: `Callout`, `Polyline` (gradient `strokeColors`, `lineCap` /
  `lineJoin` / `miterLimit`, tappable), `Polygon` (with `holes`), `Circle`,
  `Overlay` (image ground overlay), `UrlTile`, `LocalTile`, `WMSTile`,
  `Heatmap`, `Geojson` (pure-JS renderer).
- `Marker`: `image`, custom React view (rasterized), draggable, callout +
  `onSelect` / `onDeselect` / `onCalloutPress` / drag events and ref commands.
- MapView commands: `getCamera`, `getMapBoundaries`, `pointForCoordinate`,
  `coordinateForPoint`, `fitToCoordinates` / `fitToElements` /
  `fitToSuppliedMarkers`, `takeSnapshot`, `setMapBoundaries`, `getMarkersFrames`,
  `animateCamera` / `setCamera`.
- `coordinateSystem="bd09"` (in addition to `gcj02` / `wgs84`).
- `setPrivacyConsent` on iOS (PIPL compliance now on both platforms).
- `AnimatedRegion` + `Animated` MapView.

### Fixed

- A range of correctness and robustness fixes surfaced during the full code
  review and first iOS bring-up (coordinate precision, command Promise
  lifecycle, marker/overlay rendering, event bubbling, null-prop dereferences,
  initial-region timing, component registration).

### Notes

- **iOS simulator on Apple Silicon** needs an `EXCLUDED_ARCHS` workaround — AMap
  ships no arm64-simulator slice. See the README. Real devices are unaffected.
- **`<Heatmap>` on Android** needs `android.enableJetifier=true` in the host app.

## 0.1.0

Initial release — `MapView` + `Marker` MVP on Android (AMap), New Architecture
(Fabric) only.
