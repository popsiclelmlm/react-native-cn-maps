/*
 * Adapter → host callbacks. The adapter owns the provider's map + listeners and
 * translates them into these provider-agnostic ones. Like Android, the HarmonyOS
 * touch stream is provider-bound, so gesture-based presses (double tap / pan) also
 * flow through here.
 *
 * ArkTS port of core/android `adapter/CnMapAdapterDelegate.kt`.
 */
import { CnLatLng, CnMarkerEvent, CnPoi, CnPressKind, CnUserLocation, CnPoint } from './CnMapModels';

export interface CnMapAdapterDelegate {
  onMapReady(): void;

  // Map-level press. `screenPoint` is in px (the host converts to vp).
  onMapPress(kind: CnPressKind, coordinate: CnLatLng, screenPoint: CnPoint | null): void;

  // `complete` distinguishes the in-flight (onRegionChange) from the settled callback.
  onRegionChange(complete: boolean, isGesture: boolean): void;

  onPoiClick(poi: CnPoi): void;

  onUserLocationChange(location: CnUserLocation): void;

  // Marker callbacks, routed back to the owning child by childId. The coordinate is
  // the marker's current position (so drag end carries the dropped location).
  onMarkerEvent(childId: string, event: CnMarkerEvent, coordinate: CnLatLng): void;

  // A tappable overlay (polyline) was clicked.
  onOverlayPress(childId: string): void;

  // The adapter's info-window needs the child's custom callout content, if any.
  // 查证: HarmonyOS custom info-window rendering differs from Android's View-based
  // InfoWindowAdapter — on ArkUI a custom callout is an ArkUI @Builder. For the MVP
  // the host returns the marker's title/snippet text; a fully custom ArkUI callout
  // is a Phase 4 spike item. Returns null when the marker has no custom callout.
  infoWindowContentFor(childId: string): string | null;
}
