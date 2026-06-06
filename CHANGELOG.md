# Changelog

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
  initial-region timing, component registration). See
  [`docs/CODE_REVIEW_FINDINGS.md`](docs/CODE_REVIEW_FINDINGS.md).

### Notes

- **iOS simulator on Apple Silicon** needs an `EXCLUDED_ARCHS` workaround — AMap
  ships no arm64-simulator slice. See the README. Real devices are unaffected.
- **`<Heatmap>` on Android** needs `android.enableJetifier=true` in the host app.

## 0.1.0

Initial release — `MapView` + `Marker` MVP on Android (AMap), New Architecture
(Fabric) only.
