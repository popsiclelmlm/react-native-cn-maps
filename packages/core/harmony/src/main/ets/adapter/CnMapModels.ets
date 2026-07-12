/*
 * Provider-agnostic value types shared between the core host/children and a map
 * provider adapter. Nothing here references the AMap SDK or the codegen types.
 *
 * ArkTS port of core/android `adapter/CnMapModels.kt`. Kotlin data classes become
 * ArkTS interfaces (plain data) or a discriminated union (overlay models). Marker
 * icon bitmaps become `image.PixelMap` (HarmonyOS' Bitmap equivalent).
 */
import image from '@ohos.multimedia.image';

export interface CnLatLng {
  latitude: number;
  longitude: number;
}

export interface CnRegion {
  latitude: number;
  longitude: number;
  latitudeDelta: number;
  longitudeDelta: number;
}

export interface CnCamera {
  latitude: number;
  longitude: number;
  heading: number;
  pitch: number;
  zoom: number;
  altitude: number;
}

export interface CnEdgeInsets {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

export const CN_EDGE_INSETS_ZERO: CnEdgeInsets = { top: 0, right: 0, bottom: 0, left: 0 };

// On-screen pixel point (replaces android.graphics.Point). The host applies density.
export interface CnPoint {
  x: number;
  y: number;
}

// Marker model. The marker icon is rasterized (custom React children) / decoded
// (image prop) into PixelMaps by the dumb child (provider-agnostic) and handed over
// ready to use; the adapter only turns them into a provider image descriptor.
export interface CnMarkerModel {
  identifier: string | null;
  latitude: number;
  longitude: number;
  title: string | null;
  snippet: string | null;
  pinColor: string | null;
  draggable: boolean;
  anchorU: number;
  anchorV: number;
  opacity: number;
  rotation: number; // RNM clockwise degrees; the adapter converts to provider angle
  flat: boolean;
  zIndex: number;
  customBitmap: image.PixelMap | null; // rasterized custom React children
  iconBitmap: image.PixelMap | null;   // decoded `image` prop
  imageUri: string | null;             // 原始 `image` uri，由 adapter 异步解码为 PixelMap（Phase 4）
  hasInfoWindowContent: boolean;
}

// Overlay models. A `kind` discriminator replaces Kotlin's sealed class so the
// adapter can switch on the concrete type. The host builds these from child props.
export type CnOverlayKind =
  | 'polyline'
  | 'polygon'
  | 'circle'
  | 'heatmap'
  | 'urlTile'
  | 'localTile'
  | 'groundOverlay';

export interface CnOverlayModelBase {
  kind: CnOverlayKind;
}

export interface CnPolylineModel extends CnOverlayModelBase {
  kind: 'polyline';
  coordinates: CnLatLng[];
  strokeColor: number;
  strokeColors: number[];
  strokeWidth: number;
  zIndex: number;
  geodesic: boolean;
  dashed: boolean;
  lineCap: string | null;
  lineJoin: string | null;
  tappable: boolean;
}

export interface CnPolygonModel extends CnOverlayModelBase {
  kind: 'polygon';
  coordinates: CnLatLng[];
  holes: CnLatLng[][];
  strokeColor: number;
  fillColor: number;
  strokeWidth: number;
  zIndex: number;
}

export interface CnCircleModel extends CnOverlayModelBase {
  kind: 'circle';
  center: CnLatLng;
  radius: number;
  strokeColor: number;
  fillColor: number;
  strokeWidth: number;
  zIndex: number;
}

export interface CnHeatmapWeightedPoint {
  latitude: number;
  longitude: number;
  weight: number;
}

export interface CnHeatmapModel extends CnOverlayModelBase {
  kind: 'heatmap';
  points: CnHeatmapWeightedPoint[];
  radius: number;
  gradientColors: number[] | null;
  gradientStartPoints: number[] | null;
}

export interface CnUrlTileModel extends CnOverlayModelBase {
  kind: 'urlTile';
  urlTemplate: string | null;
  minimumZ: number;
  maximumZ: number;
  tileSize: number;
  flipY: boolean;
  wms: boolean;
  zIndex: number;
  diskCacheDir: string | null;
}

export interface CnLocalTileModel extends CnOverlayModelBase {
  kind: 'localTile';
  pathTemplate: string | null;
  tileSize: number;
  useAssets: boolean;
  zIndex: number;
}

export interface CnGroundOverlayModel extends CnOverlayModelBase {
  kind: 'groundOverlay';
  southWest: CnLatLng | null;
  northEast: CnLatLng | null;
  bitmap: image.PixelMap | null;
  imageUri: string | null;             // 原始 `image` uri，由 adapter 异步解码为 PixelMap（Phase 4）
  bearing: number;
  opacity: number;
  zIndex: number;
}

export type CnOverlayModel =
  | CnPolylineModel
  | CnPolygonModel
  | CnCircleModel
  | CnHeatmapModel
  | CnUrlTileModel
  | CnLocalTileModel
  | CnGroundOverlayModel;

// Point-of-interest tapped on the basemap.
export interface CnPoi {
  placeId: string | null;
  name: string | null;
  latitude: number;
  longitude: number;
}

// User-location snapshot surfaced to the host (provider-agnostic scalars).
export interface CnUserLocation {
  latitude: number;
  longitude: number;
  altitude: number;
  accuracy: number;
  speed: number;
  heading: number;
  isFromMockProvider: boolean;
}

// Reverse-geocoded address surfaced to the host (mirrors the JS `Address` type).
export interface CnAddress {
  name: string;
  thoroughfare: string;
  subThoroughfare: string;
  locality: string;
  subLocality: string;
  administrativeArea: string;
  subAdministrativeArea: string;
  postalCode: string;
  countryCode: string;
  country: string;
}

// Map-level press kinds that share the { coordinate, position } payload.
export enum CnPressKind {
  PRESS,
  LONG_PRESS,
  DOUBLE_PRESS,
  PAN_DRAG,
}

// Marker callbacks the adapter routes back to a child by childId.
export enum CnMarkerEvent {
  PRESS,
  SELECT,
  DESELECT,
  CALLOUT_PRESS,
  DRAG_START,
  DRAG,
  DRAG_END,
}
