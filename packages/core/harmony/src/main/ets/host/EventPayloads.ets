/*
 * Typed event / command-result payloads emitted to JS. ArkTS forbids untyped object
 * literals (arkts-no-untyped-obj-literals), so every emitted payload needs an
 * explicit interface. Shapes mirror the codegen-facing events declared in core JS
 * `src/MapViewNativeComponent.ts` (NativeMapPressEvent, NativeRegionChangeEvent, …)
 * — i.e. derived from the JS spec, not from any provider SDK.
 */

export interface LatLngP {
  latitude: number;
  longitude: number;
}

export interface PositionP {
  x: number;
  y: number;
}

export interface RegionP {
  latitude: number;
  longitude: number;
  latitudeDelta: number;
  longitudeDelta: number;
}

// Empty payload (onMapReady / onMapLoaded / empty command results).
export interface EmptyP {}

export interface PressEventP {
  coordinate: LatLngP;
  position: PositionP;
}

export interface RegionChangeEventP {
  region: RegionP;
  isGesture: boolean;
}

export interface PoiClickEventP {
  coordinate: LatLngP;
  position: PositionP;
  placeId?: string;
  name?: string;
}

export interface UserLocationP {
  latitude: number;
  longitude: number;
  altitude: number;
  accuracy: number;
  speed: number;
  heading: number;
  isFromMockProvider: boolean;
}

export interface UserLocationChangeEventP {
  coordinate: UserLocationP;
}

// Host-level marker/overlay events carry childId (see CnMapHostController).
export interface MarkerEventP {
  childId: string;
  coordinate: LatLngP;
}

// Marker 事件直接 emit 到 Marker 子节点自己的 tag（见 CnMapHostController.onMarkerEvent），
// payload 与 Marker codegen（generated/components/RNMapsMarker.ts）一致：仅 coordinate。
export interface MarkerChildEventP {
  coordinate: LatLngP;
}

export interface OverlayPressEventP {
  childId: string;
}

// onCommandResult: { id, data(JSON string) }.
export interface CommandResultEventP {
  id: number;
  data: string;
}

// --- Command-result DATA payloads (JSON.stringified into CommandResultEventP.data) ---

export interface CameraDataP {
  latitude: number;
  longitude: number;
  heading: number;
  pitch: number;
  zoom: number;
  altitude: number;
}

export interface BoundariesDataP {
  northEast: LatLngP;
  southWest: LatLngP;
}

export interface SnapshotDataP {
  uri: string;
}

export interface AddressDataP {
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

export interface FrameRectP {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface MarkerFrameP {
  point: PositionP;
  frame: FrameRectP;
}

export const EMPTY_PAYLOAD: EmptyP = {};
