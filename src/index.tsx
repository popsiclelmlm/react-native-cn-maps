export { MapView as default, MapView, AnimatedMapView } from './MapView';

import Marker from './MapMarker';
import Overlay from './MapOverlay';

export { default as Marker, Marker as MapMarker } from './MapMarker';
export type { MapMarkerProps } from './MapMarker';

/** RNM parity: `Animated`-wrapped Marker (also available as `Marker.Animated`). */
export const MarkerAnimated = Marker.Animated;

export { default as Polyline } from './MapPolyline';
export type { MapPolylineProps } from './MapPolyline';

export { default as Polygon } from './MapPolygon';
export type { MapPolygonProps } from './MapPolygon';

export { default as Circle } from './MapCircle';
export type { MapCircleProps } from './MapCircle';

export { default as Callout } from './MapCallout';
export type { MapCalloutProps } from './MapCallout';

export { default as CalloutSubview } from './MapCalloutSubview';
export type { MapCalloutSubviewProps } from './MapCalloutSubview';

export { default as Overlay } from './MapOverlay';
export type { MapOverlayProps } from './MapOverlay';

/** RNM parity: `Animated`-wrapped Overlay (also available as `Overlay.Animated`). */
export const OverlayAnimated = Overlay.Animated;

export { default as Geojson } from './MapGeojson';
export type { MapGeojsonProps } from './MapGeojson';

export { default as Heatmap } from './MapHeatmap';
export type { MapHeatmapProps } from './MapHeatmap';

export { default as UrlTile } from './MapUrlTile';
export type { MapUrlTileProps } from './MapUrlTile';

export { default as WMSTile } from './MapWMSTile';
export type { MapWMSTileProps } from './MapWMSTile';

export { default as LocalTile } from './MapLocalTile';
export type { MapLocalTileProps } from './MapLocalTile';

export { AnimatedRegion } from './AnimatedRegion';

/**
 * RNM parity: the package-level `Animated` export is the `Animated`-wrapped
 * MapView, NOT React Native's `Animated` namespace. Import the latter from
 * `react-native` directly.
 */
export { AnimatedMapView as Animated } from './MapView';

export {
  MAP_TYPES,
  PROVIDER_DEFAULT,
  PROVIDER_GOOGLE,
  type MapTypes,
} from './constants';

export type {
  ActiveIndoorLevel,
  Address,
  BoundingBox,
  CalloutPressEvent,
  CalloutProps,
  CalloutSubviewProps,
  Camera,
  CameraZoomRange,
  ChangeEvent,
  CircleProps,
  ClickEvent,
  CoordinateSystem,
  Details,
  EdgePadding,
  FitToCoordinatesOptions,
  FitToOptions,
  FitToSuppliedMarkersOptions,
  Frame,
  GeojsonProps,
  HeatmapGradient,
  HeatmapPoint,
  HeatmapProps,
  IndoorBuilding,
  IndoorBuildingEvent,
  IndoorLevel,
  IndoorLevelActivatedEvent,
  KmlMapEvent,
  KmlMarker,
  LatLng,
  LineCapType,
  LineJoinType,
  LocalTileProps,
  LongPressEvent,
  MapEvent,
  MapMarkerHandle,
  MapPressEvent,
  MapProvider,
  MapStyleElement,
  MapType,
  MapViewHandle,
  MapViewProps,
  MarkerDeselectEvent,
  MarkerDragEvent,
  MarkerDragStartEndEvent,
  MarkerImageSource,
  MarkerPressEvent,
  MarkerProps,
  MarkerSelectEvent,
  MKPointOfInterestCategoryType,
  OverlayProps,
  PanDragEvent,
  PoiClickEvent,
  Point,
  PolygonPressEvent,
  PolygonProps,
  PolylineProps,
  Provider,
  Region,
  RegionChangeEvent,
  SnapshotOptions,
  UrlTileProps,
  UserInterfaceStyle,
  UserLocationChangeEvent,
  WMSTileProps,
} from './types';
