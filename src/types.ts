import type { ReactNode } from 'react';
import type {
  ColorValue,
  ImageRequireSource,
  ImageURISource,
  ViewProps,
} from 'react-native';

// ---------- Coordinate primitives ----------

export type MapProvider = 'amap' | 'baidu' | 'tencent';

export type CoordinateSystem = 'gcj02' | 'wgs84' | 'bd09';

export type LatLng = {
  latitude: number;
  longitude: number;
};

export type Point = {
  x: number;
  y: number;
};

export type Region = LatLng & {
  latitudeDelta: number;
  longitudeDelta: number;
};

export type BoundingBox = {
  northEast: LatLng;
  southWest: LatLng;
};

// ---------- Map enums ----------

export type MapType =
  | 'standard'
  | 'satellite'
  | 'hybrid'
  | 'terrain'
  | 'none'
  | 'mutedStandard';

export type UserInterfaceStyle = 'light' | 'dark';

export type LineCapType = 'butt' | 'round' | 'square';

export type LineJoinType = 'miter' | 'round' | 'bevel';

// ---------- Camera / EdgePadding ----------

export type Camera = {
  center: LatLng;
  pitch: number;
  heading: number;
  altitude?: number;
  zoom: number;
};

export type EdgePadding = {
  top: number;
  right: number;
  bottom: number;
  left: number;
};

// ---------- Address (parity with RNM) ----------

export type Address = {
  name?: string;
  thoroughfare?: string;
  subThoroughfare?: string;
  locality?: string;
  subLocality?: string;
  administrativeArea?: string;
  subAdministrativeArea?: string;
  postalCode?: string;
  countryCode?: string;
  country?: string;
};

// ---------- Custom map style ----------

export type MapStyleElement = {
  featureType?: string;
  elementType?: string;
  stylers: ReadonlyArray<Record<string, string | number | boolean>>;
};

// ---------- KML ----------

export type KmlMarker = {
  id: string;
  title: string;
  description: string;
  coordinate: LatLng;
  position: Point;
};

// ---------- Event envelope ----------

export type MapEvent<T = Record<string, unknown>> = {
  nativeEvent: T;
};

/**
 * Second argument that RNM's `onRegionChange{,Complete}` callbacks receive.
 * Will be wired in M2 alongside the full region-change overhaul; exported now
 * so consumers can type their handlers.
 */
export type Details = {
  isGesture?: boolean;
};

export type RegionChangeEvent = MapEvent<{
  region: Region;
  isGesture?: boolean;
}>;

export type MapPressEvent = MapEvent<{
  coordinate: LatLng;
  position: Point;
  action?: 'press';
}>;

export type LongPressEvent = MapEvent<{
  coordinate: LatLng;
  position: Point;
  action?: 'long-press';
}>;

export type PanDragEvent = MapEvent<{
  coordinate: LatLng;
  position: Point;
}>;

export type PoiClickEvent = MapEvent<{
  coordinate: LatLng;
  placeId?: string;
  name?: string;
}>;

export type UserLocationChangeEvent = MapEvent<{
  coordinate?: LatLng & {
    altitude?: number;
    timestamp?: number;
    accuracy?: number;
    altitudeAccuracy?: number;
    heading?: number;
    speed?: number;
    isFromMockProvider?: boolean;
  };
}>;

export type IndoorBuildingEvent = MapEvent<{
  IndoorBuilding: {
    underground: boolean;
    activeLevelIndex: number;
    levels: ReadonlyArray<{
      index: number;
      name: string;
      shortName: string;
    }>;
  };
}>;

export type IndoorLevelActivatedEvent = MapEvent<{
  IndoorLevel: {
    activeLevelIndex: number;
    name: string;
    shortName: string;
  };
}>;

export type KmlMapEvent = MapEvent<{
  markers: ReadonlyArray<KmlMarker>;
}>;

export type MarkerPressEvent = MapEvent<{
  coordinate: LatLng;
  identifier: string;
  position?: Point;
  action?: 'marker-press';
}>;

export type MarkerSelectEvent = MapEvent<{
  coordinate: LatLng;
  identifier: string;
  action?: 'marker-select';
}>;

export type MarkerDeselectEvent = MapEvent<{
  coordinate: LatLng;
  identifier: string;
  action?: 'marker-deselect';
}>;

export type MarkerDragEvent = MapEvent<{
  coordinate: LatLng;
  identifier?: string;
}>;

export type MarkerDragStartEndEvent = MarkerDragEvent;

export type CalloutPressEvent = MapEvent<{
  action?: 'callout-press' | 'marker-overlay-press';
  identifier?: string;
  point?: Point;
  frame?: { x: number; y: number; width: number; height: number };
}>;

// ---------- MapView props ----------

export type MapViewProps = ViewProps & {
  provider?: MapProvider;
  coordinateSystem?: CoordinateSystem;

  // Region / camera
  initialRegion?: Region;
  region?: Region;
  initialCamera?: Camera;
  camera?: Camera;

  // Map appearance
  mapType?: MapType;
  customMapStyle?: ReadonlyArray<MapStyleElement>;
  userInterfaceStyle?: UserInterfaceStyle;
  tintColor?: ColorValue;
  mapPadding?: EdgePadding;

  // Zoom
  minZoomLevel?: number;
  maxZoomLevel?: number;

  // Gesture toggles
  zoomEnabled?: boolean;
  zoomTapEnabled?: boolean;
  zoomControlEnabled?: boolean;
  scrollEnabled?: boolean;
  scrollDuringRotateOrZoomEnabled?: boolean;
  rotateEnabled?: boolean;
  pitchEnabled?: boolean;

  // Display toggles
  showsUserLocation?: boolean;
  followsUserLocation?: boolean;
  userLocationPriority?: 'balanced' | 'high' | 'low' | 'passive';
  userLocationUpdateInterval?: number;
  userLocationFastestInterval?: number;
  userLocationAnnotationTitle?: string;
  showsMyLocationButton?: boolean;
  showsCompass?: boolean;
  showsScale?: boolean;
  showsTraffic?: boolean;
  showsBuildings?: boolean;
  showsIndoors?: boolean;
  showsIndoorLevelPicker?: boolean;
  showsPointsOfInterest?: boolean;

  // Loading state
  loadingEnabled?: boolean;
  loadingIndicatorColor?: ColorValue;
  loadingBackgroundColor?: ColorValue;

  // Android-only toggles
  toolbarEnabled?: boolean;
  liteMode?: boolean;
  cacheEnabled?: boolean;
  paddingAdjustmentBehavior?: 'always' | 'automatic' | 'never';

  // KML
  kmlSrc?: string;

  // Compass placement
  legalLabelInsets?: EdgePadding;
  compassOffset?: Point;

  children?: ReactNode;

  // Region / camera events
  onRegionChange?: (event: RegionChangeEvent) => void;
  onRegionChangeComplete?: (event: RegionChangeEvent) => void;

  // Map lifecycle
  onMapReady?: () => void;
  onMapLoaded?: () => void;

  // Map gestures
  onPress?: (event: MapPressEvent) => void;
  onLongPress?: (event: LongPressEvent) => void;
  onDoublePress?: (event: MapPressEvent) => void;
  onPanDrag?: (event: PanDragEvent) => void;
  onPoiClick?: (event: PoiClickEvent) => void;

  // User location
  onUserLocationChange?: (event: UserLocationChangeEvent) => void;

  // Indoor
  onIndoorBuildingFocused?: (event: IndoorBuildingEvent) => void;
  onIndoorLevelActivated?: (event: IndoorLevelActivatedEvent) => void;

  // KML
  onKmlReady?: (event: KmlMapEvent) => void;

  // Marker drag (forwarded by Marker child to MapView, RNM parity)
  onMarkerPress?: (event: MarkerPressEvent) => void;
  onMarkerSelect?: (event: MarkerSelectEvent) => void;
  onMarkerDeselect?: (event: MarkerDeselectEvent) => void;
  onMarkerDragStart?: (event: MarkerDragStartEndEvent) => void;
  onMarkerDrag?: (event: MarkerDragEvent) => void;
  onMarkerDragEnd?: (event: MarkerDragStartEndEvent) => void;
  onCalloutPress?: (event: CalloutPressEvent) => void;
};

// ---------- Marker props ----------

export type MarkerImageSource =
  | ImageURISource
  | ImageRequireSource
  | ReadonlyArray<ImageURISource>;

export type MarkerProps = ViewProps & {
  coordinate: LatLng;
  identifier?: string;
  title?: string;
  description?: string;

  // Appearance
  pinColor?: ColorValue;
  image?: MarkerImageSource;
  icon?: MarkerImageSource;
  anchor?: Point;
  centerOffset?: Point;
  calloutAnchor?: Point;
  opacity?: number;
  rotation?: number;
  flat?: boolean;
  zIndex?: number;

  // Behavior
  draggable?: boolean;
  tappable?: boolean;
  tracksViewChanges?: boolean;
  tracksInfoWindowChanges?: boolean;
  stopPropagation?: boolean;
  isPreselected?: boolean;

  // Events
  onPress?: (event: MarkerPressEvent) => void;
  onSelect?: (event: MarkerSelectEvent) => void;
  onDeselect?: (event: MarkerDeselectEvent) => void;
  onCalloutPress?: (event: CalloutPressEvent) => void;
  onDragStart?: (event: MarkerDragStartEndEvent) => void;
  onDrag?: (event: MarkerDragEvent) => void;
  onDragEnd?: (event: MarkerDragStartEndEvent) => void;

  children?: ReactNode;
};

// ---------- Callout props ----------

export type CalloutProps = ViewProps & {
  tooltip?: boolean;
  alphaHitTest?: boolean;
  onPress?: (event: CalloutPressEvent) => void;
  children?: ReactNode;
};

export type CalloutSubviewProps = ViewProps & {
  onPress?: (event: CalloutPressEvent) => void;
  children?: ReactNode;
};

// ---------- Polyline / Polygon / Circle ----------

export type PolylineProps = ViewProps & {
  coordinates: ReadonlyArray<LatLng>;
  strokeColor?: ColorValue;
  strokeColors?: ReadonlyArray<ColorValue>;
  strokeWidth?: number;
  lineDashPhase?: number;
  lineDashPattern?: ReadonlyArray<number>;
  lineCap?: LineCapType;
  lineJoin?: LineJoinType;
  miterLimit?: number;
  geodesic?: boolean;
  zIndex?: number;
  tappable?: boolean;
  onPress?: (event: MapPressEvent) => void;
};

export type PolygonProps = ViewProps & {
  coordinates: ReadonlyArray<LatLng>;
  holes?: ReadonlyArray<ReadonlyArray<LatLng>>;
  strokeColor?: ColorValue;
  strokeWidth?: number;
  fillColor?: ColorValue;
  lineDashPhase?: number;
  lineDashPattern?: ReadonlyArray<number>;
  lineCap?: LineCapType;
  lineJoin?: LineJoinType;
  miterLimit?: number;
  geodesic?: boolean;
  zIndex?: number;
  tappable?: boolean;
  onPress?: (event: MapPressEvent) => void;
};

export type CircleProps = ViewProps & {
  center: LatLng;
  radius: number;
  strokeColor?: ColorValue;
  strokeWidth?: number;
  fillColor?: ColorValue;
  lineDashPhase?: number;
  lineDashPattern?: ReadonlyArray<number>;
  lineCap?: LineCapType;
  lineJoin?: LineJoinType;
  miterLimit?: number;
  zIndex?: number;
  tappable?: boolean;
  onPress?: (event: MapPressEvent) => void;
};

// ---------- Tile overlays ----------

export type UrlTileProps = ViewProps & {
  urlTemplate: string;
  minimumZ?: number;
  maximumZ?: number;
  maximumNativeZ?: number;
  zIndex?: number;
  tileSize?: number;
  doubleTileSize?: boolean;
  flipY?: boolean;
  opacity?: number;
  shouldReplaceMapContent?: boolean;
  tileCachePath?: string;
  tileCacheMaxAge?: number;
  offlineMode?: boolean;
};

export type WMSTileProps = UrlTileProps;

export type LocalTileProps = ViewProps & {
  pathTemplate: string;
  tileSize?: number;
  useAssets?: boolean;
  zIndex?: number;
};

// ---------- Other overlays ----------

export type OverlayProps = ViewProps & {
  image: ImageURISource | ImageRequireSource;
  bounds: [LatLng, LatLng];
  bearing?: number;
  opacity?: number;
  tappable?: boolean;
  zIndex?: number;
  onPress?: (event: MapPressEvent) => void;
};

export type GeojsonProps = ViewProps & {
  // Intentionally loose — matches RNM's `Geojson` shape.
  geojson: Record<string, unknown>;
  strokeColor?: ColorValue;
  fillColor?: ColorValue;
  strokeWidth?: number;
  lineDashPhase?: number;
  lineDashPattern?: ReadonlyArray<number>;
  markerComponent?: ReactNode;
  title?: string;
  zIndex?: number;
  tappable?: boolean;
  tracksViewChanges?: boolean;
  image?: MarkerImageSource;
  pinColor?: ColorValue;
  onPress?: (event: MapPressEvent) => void;
};

export type HeatmapPoint = LatLng & {
  weight?: number;
};

export type HeatmapGradient = {
  colors: ReadonlyArray<ColorValue>;
  startPoints: ReadonlyArray<number>;
  colorMapSize: number;
};

export type HeatmapProps = ViewProps & {
  points: ReadonlyArray<HeatmapPoint>;
  radius?: number;
  opacity?: number;
  gradient?: HeatmapGradient;
};

// ---------- MapView imperative handle ----------

export type FitToCoordinatesOptions = {
  edgePadding?: EdgePadding;
  animated?: boolean;
};

export type FitToSuppliedMarkersOptions = FitToCoordinatesOptions;

export type SnapshotOptions = {
  width?: number;
  height?: number;
  region?: Region;
  format?: 'png' | 'jpg';
  quality?: number;
  result?: 'file' | 'base64';
};

export type MapViewHandle = {
  // Region / camera
  animateToRegion: (region: Region, duration?: number) => void;
  animateCamera?: (
    camera: Partial<Camera>,
    opts?: { duration?: number }
  ) => void;
  setCamera?: (camera: Partial<Camera>) => void;
  getCamera?: () => Promise<Camera>;

  // Bounds / fit
  fitToElements?: (options?: FitToCoordinatesOptions) => void;
  fitToSuppliedMarkers?: (
    markerIDs: ReadonlyArray<string>,
    options?: FitToSuppliedMarkersOptions
  ) => void;
  fitToCoordinates?: (
    coordinates: ReadonlyArray<LatLng>,
    options?: FitToCoordinatesOptions
  ) => void;
  setMapBoundaries?: (northEast: LatLng, southWest: LatLng) => void;
  getMapBoundaries?: () => Promise<BoundingBox>;

  // Coordinate <-> point projection
  pointForCoordinate?: (coordinate: LatLng) => Promise<Point>;
  coordinateForPoint?: (point: Point) => Promise<LatLng>;

  // Misc
  getMarkersFrames?: (onlyVisible?: boolean) => Promise<
    Record<
      string,
      {
        point: Point;
        frame: { x: number; y: number; width: number; height: number };
      }
    >
  >;
  setIndoorActiveLevelIndex?: (index: number) => void;
  addressForCoordinate?: (coordinate: LatLng) => Promise<Address>;
  takeSnapshot?: (options?: SnapshotOptions) => Promise<string>;
};
