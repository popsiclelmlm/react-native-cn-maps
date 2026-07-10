/*
 * The provider-agnostic contract the core host (CnMapHostComponent) talks to. A
 * concrete adapter (e.g. AMapAdapter) owns the real SDK map controller, its
 * listeners and all SDK calls; the host owns the Fabric lifecycle, child routing
 * and event dispatch. No method here exposes a provider (AMap) or codegen type.
 *
 * ArkTS port of core/android `adapter/CnMapAdapter.kt`, with one structural
 * adaptation for ArkUI: Android/iOS hand back a `View` object; ArkUI is
 * declarative, so the provider instead exposes a `mapBuilder()` (a WrappedBuilder)
 * that renders its ArkUI map component and binds the controller to the adapter on
 * map-ready. The host renders that builder in its own build().
 */
import common from '@ohos.app.ability.common';
import {
  CnAddress, CnCamera, CnEdgeInsets, CnLatLng, CnMarkerModel, CnOverlayModel, CnRegion, CnPoint
} from './CnMapModels';
import { CnMapAdapterDelegate } from './CnMapAdapterDelegate';
import { OverlayHandle } from './OverlayHandle';

export interface CnMapAdapter {
  // Provider identity ("amap"/"baidu"/"tencent"); the host tracks which is mounted.
  readonly providerName: string;
  delegate: CnMapAdapterDelegate | null;

  // True once the underlying ArkUI map controller is attached and usable.
  isReady(): boolean;

  // Lifecycle (the host forwards these from its own lifecycle/size callbacks).
  onResume(): void;
  onPause(): void;
  onDestroy(): void;
  onSizeChanged(): void;
  // Called from the host layout once the map is sized, so a pending initial
  // viewport can be applied (mirrors iOS -didLayout / Android applyPendingInitial).
  didLayout(): void;
  // Clear all markers/overlays and viewport state for view recycling.
  reset(): void;

  // Configuration -------------------------------------------------------------
  setMapType(value: string | null): void;
  setUserInterfaceStyle(value: string | null): void;
  setMinZoomLevel(value: number): void;
  setMaxZoomLevel(value: number): void;
  setZoomEnabled(value: boolean): void;
  setZoomControlEnabled(value: boolean): void;
  setScrollEnabled(value: boolean): void;
  setRotateEnabled(value: boolean): void;
  setPitchEnabled(value: boolean): void;
  setShowsUserLocation(value: boolean): void;
  setShowsMyLocationButton(value: boolean): void;
  setShowsCompass(value: boolean): void;
  setShowsScale(value: boolean): void;
  setShowsTraffic(value: boolean): void;
  setShowsBuildings(value: boolean): void;
  setShowsIndoors(value: boolean): void;
  setShowsIndoorLevelPicker(value: boolean): void;
  setShowsPointsOfInterest(value: boolean): void;

  // Viewport ------------------------------------------------------------------
  setInitialRegion(region: CnRegion): void;
  setRegion(region: CnRegion): void;
  setInitialCamera(camera: CnCamera): void;
  setCamera(camera: CnCamera): void;
  animateToRegion(region: CnRegion, duration: number): void;
  applyCamera(camera: CnCamera, animated: boolean, duration: number): void;
  currentRegion(): CnRegion | null;
  currentCamera(): CnCamera;
  // northeast / southwest of the visible region, or null if unavailable.
  mapBoundaries(): [CnLatLng, CnLatLng] | null;
  fitToCoordinates(coordinates: CnLatLng[], edgePadding: CnEdgeInsets, animated: boolean): void;
  fitToMarkers(handles: OverlayHandle[], edgePadding: CnEdgeInsets, animated: boolean): void;
  setMapBoundaries(ne: CnLatLng, sw: CnLatLng): void;

  // Projection (px; the host applies density). ---------------------------------
  pointForCoordinate(coordinate: CnLatLng): CnPoint | null;
  coordinateForPoint(xPx: number, yPx: number): CnLatLng | null;

  // Snapshot (async; replies with a file:// uri / base64 / "" on failure). -----
  takeSnapshot(
    width: number,
    height: number,
    format: string,
    quality: number,
    result: string,
    completion: (uri: string) => void
  ): void;

  // Reverse geocoding (async). Providers without a bundled geocoder call
  // completion(null); AMap implements a real lookup.
  addressForCoordinate(
    latitude: number,
    longitude: number,
    completion: (address: CnAddress | null) => void
  ): void;

  // Markers -------------------------------------------------------------------
  addMarker(model: CnMarkerModel, childId: string): OverlayHandle;
  updateMarker(handle: OverlayHandle, model: CnMarkerModel): void;
  removeMarker(handle: OverlayHandle): void;
  showCallout(handle: OverlayHandle): void;
  hideCallout(handle: OverlayHandle): void;
  redrawCallout(handle: OverlayHandle): void;
  animateMarker(handle: OverlayHandle, latitude: number, longitude: number, duration: number): void;
  markerScreenPoint(handle: OverlayHandle): CnPoint | null;
  markerPosition(handle: OverlayHandle): CnLatLng | null;

  // Overlays ------------------------------------------------------------------
  addOverlay(model: CnOverlayModel, childId: string): OverlayHandle;
  updateOverlay(handle: OverlayHandle, model: CnOverlayModel): void;
  removeOverlay(handle: OverlayHandle): void;
}

/*
 * A factory + privacy entry point a provider package registers. Kept separate from
 * the per-map adapter so the registry can create maps and fan privacy out without a
 * live map instance.
 *
 * `mapBuilder()` returns the provider's ArkUI map builder. The host invokes it in
 * build() passing the adapter created via create(); the provider's builder renders
 * its ArkUI map component and, on map-ready, binds the controller to that adapter.
 * 查证: cross-HAR @Builder / wrapBuilder() usage against the pinned ArkUI/RNOH
 * version — this builder must accept the CnMapAdapter so the provider can attach
 * the controller to the right adapter instance.
 */
export type CnMapBuilder = WrappedBuilder<[CnMapAdapter]>;

export interface CnMapAdapterFactory {
  // Provider name this factory produces; the registry matches it against the JS
  // `provider` prop.
  readonly providerName: string;
  create(context: common.Context): CnMapAdapter;
  mapBuilder(): CnMapBuilder;
  applyPrivacyConsent(context: common.Context, agreed: boolean, contains: boolean, shown: boolean): void;
}
