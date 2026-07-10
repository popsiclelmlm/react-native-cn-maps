// codegenNativeCommands / codegenNativeComponent 在 RNOH 的 react-native 重定向入口(0.72)未导出，
// 从深路径默认导入：该文件 0.72/0.85 都有，其内部相对依赖会被 RNOH 重定向到 harmony 实现，
// 且 codegen 仅按本地名识别——三端通用。
// eslint-disable-next-line @react-native/no-deep-imports
import codegenNativeCommands from 'react-native/Libraries/Utilities/codegenNativeCommands';
// eslint-disable-next-line @react-native/no-deep-imports
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import {
  type ColorValue,
  type HostComponent,
  type ViewProps,
} from 'react-native';
import type {
  BubblingEventHandler,
  DirectEventHandler,
  Double,
  Int32,
  WithDefault,
} from './codegen-types';

export type NativeRegion = Readonly<{
  latitude: Double;
  longitude: Double;
  latitudeDelta: Double;
  longitudeDelta: Double;
}>;

// `center` is flattened to latitude/longitude so the struct stays codegen
// friendly (no nested object props). JS rebuilds the RNM `{ center: LatLng }`
// shape on the way in/out.
export type NativeCamera = Readonly<{
  latitude: Double;
  longitude: Double;
  heading: Double;
  pitch: Double;
  zoom: Double;
  altitude: Double;
}>;

export type NativeEdgePadding = Readonly<{
  top: Double;
  right: Double;
  bottom: Double;
  left: Double;
}>;

export type NativeRegionChangeEvent = Readonly<{
  region: Readonly<{
    latitude: Double;
    longitude: Double;
    latitudeDelta: Double;
    longitudeDelta: Double;
  }>;
  isGesture?: boolean;
}>;

// Shared by onPress / onLongPress / onDoublePress / onPanDrag.
export type NativeMapPressEvent = Readonly<{
  coordinate: Readonly<{
    latitude: Double;
    longitude: Double;
  }>;
  position: Readonly<{
    x: Double;
    y: Double;
  }>;
}>;

export type NativePoiClickEvent = Readonly<{
  placeId?: string;
  name?: string;
  coordinate: Readonly<{
    latitude: Double;
    longitude: Double;
  }>;
  position?: Readonly<{
    x: Double;
    y: Double;
  }>;
}>;

export type NativeUserLocationChangeEvent = Readonly<{
  coordinate?: Readonly<{
    latitude: Double;
    longitude: Double;
    altitude: Double;
    accuracy: Double;
    speed: Double;
    heading: Double;
    isFromMockProvider?: boolean;
  }>;
}>;

export interface NativeProps extends ViewProps {
  provider?: WithDefault<string, 'amap'>;
  coordinateSystem?: WithDefault<string, 'gcj02'>;

  // Region / camera
  initialRegion?: NativeRegion;
  region?: NativeRegion;
  initialCamera?: NativeCamera;
  camera?: NativeCamera;

  // Appearance
  mapType?: WithDefault<string, 'standard'>;
  customMapStyle?: string; // JSON-stringified MapStyleElement[] (see JS facade)
  userInterfaceStyle?: WithDefault<string, 'system'>;
  tintColor?: ColorValue;
  mapPadding?: NativeEdgePadding;
  kmlSrc?: string;

  // Zoom
  minZoomLevel?: WithDefault<Double, 3>;
  maxZoomLevel?: WithDefault<Double, 20>;

  // Gesture toggles
  zoomEnabled?: WithDefault<boolean, true>;
  zoomTapEnabled?: WithDefault<boolean, true>;
  zoomControlEnabled?: WithDefault<boolean, false>;
  scrollEnabled?: WithDefault<boolean, true>;
  scrollDuringRotateOrZoomEnabled?: WithDefault<boolean, true>;
  rotateEnabled?: WithDefault<boolean, true>;
  pitchEnabled?: WithDefault<boolean, true>;

  // Display toggles
  showsUserLocation?: WithDefault<boolean, false>;
  showsMyLocationButton?: WithDefault<boolean, true>;
  showsCompass?: WithDefault<boolean, true>;
  showsScale?: WithDefault<boolean, false>;
  showsTraffic?: WithDefault<boolean, false>;
  showsBuildings?: WithDefault<boolean, true>;
  showsIndoors?: WithDefault<boolean, true>;
  showsIndoorLevelPicker?: WithDefault<boolean, false>;
  showsPointsOfInterest?: WithDefault<boolean, true>;

  // Loading state
  loadingEnabled?: WithDefault<boolean, false>;
  loadingIndicatorColor?: ColorValue;
  loadingBackgroundColor?: ColorValue;

  // Android-only
  toolbarEnabled?: WithDefault<boolean, true>;
  liteMode?: WithDefault<boolean, false>;
  cacheEnabled?: WithDefault<boolean, false>;

  // Region / camera events
  onRegionChange?: DirectEventHandler<NativeRegionChangeEvent>;
  onRegionChangeComplete?: DirectEventHandler<NativeRegionChangeEvent>;

  // Lifecycle
  onMapReady?: DirectEventHandler<Readonly<{}>>;
  onMapLoaded?: DirectEventHandler<Readonly<{}>>;

  // Gestures
  // onPress is Bubbling (not Direct): iOS core registers `topPress` as bubbling,
  // so a direct registration throws "Event cannot be both direct and bubbling".
  onPress?: BubblingEventHandler<NativeMapPressEvent>;
  onLongPress?: DirectEventHandler<NativeMapPressEvent>;
  onDoublePress?: DirectEventHandler<NativeMapPressEvent>;
  onPanDrag?: DirectEventHandler<NativeMapPressEvent>;
  onPoiClick?: DirectEventHandler<NativePoiClickEvent>;

  // User location
  onUserLocationChange?: DirectEventHandler<NativeUserLocationChangeEvent>;

  // Result channel for Promise-returning ref methods. Native serializes the
  // result to JSON keyed by the JS-generated request id (RNM's Fabric pattern).
  onCommandResult?: DirectEventHandler<NativeCommandResultEvent>;
}

export type NativeCommandResultEvent = Readonly<{
  id: Int32;
  data: string;
}>;

type ComponentType = HostComponent<NativeProps>;

// Geometry args that codegen commands can't pass as objects cross as JSON
// strings (coordinates, edgePadding, marker id lists).
interface NativeCommands {
  animateToRegion: (
    viewRef: React.ElementRef<ComponentType>,
    latitude: Double,
    longitude: Double,
    latitudeDelta: Double,
    longitudeDelta: Double,
    duration: Int32
  ) => void;
  animateCamera: (
    viewRef: React.ElementRef<ComponentType>,
    latitude: Double,
    longitude: Double,
    heading: Double,
    pitch: Double,
    zoom: Double,
    duration: Int32
  ) => void;
  setCamera: (
    viewRef: React.ElementRef<ComponentType>,
    latitude: Double,
    longitude: Double,
    heading: Double,
    pitch: Double,
    zoom: Double
  ) => void;
  fitToCoordinates: (
    viewRef: React.ElementRef<ComponentType>,
    coordinatesJSON: string,
    edgePaddingJSON: string,
    animated: boolean
  ) => void;
  fitToElements: (
    viewRef: React.ElementRef<ComponentType>,
    animated: boolean
  ) => void;
  fitToSuppliedMarkers: (
    viewRef: React.ElementRef<ComponentType>,
    markerIDsJSON: string,
    edgePaddingJSON: string,
    animated: boolean
  ) => void;
  // Queries — result delivered via onCommandResult keyed by requestId.
  getCamera: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: Int32
  ) => void;
  getMapBoundaries: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: Int32
  ) => void;
  pointForCoordinate: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: Int32,
    latitude: Double,
    longitude: Double
  ) => void;
  coordinateForPoint: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: Int32,
    x: Double,
    y: Double
  ) => void;
  addressForCoordinate: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: Int32,
    latitude: Double,
    longitude: Double
  ) => void;
  takeSnapshot: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: Int32,
    width: Int32,
    height: Int32,
    format: string,
    quality: Double,
    result: string
  ) => void;
  setMapBoundaries: (
    viewRef: React.ElementRef<ComponentType>,
    neLatitude: Double,
    neLongitude: Double,
    swLatitude: Double,
    swLongitude: Double
  ) => void;
  getMarkersFrames: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: Int32,
    onlyVisible: boolean
  ) => void;
}

export const Commands: NativeCommands = codegenNativeCommands<NativeCommands>({
  supportedCommands: [
    'animateToRegion',
    'animateCamera',
    'setCamera',
    'fitToCoordinates',
    'fitToElements',
    'fitToSuppliedMarkers',
    'getCamera',
    'getMapBoundaries',
    'pointForCoordinate',
    'coordinateForPoint',
    'addressForCoordinate',
    'takeSnapshot',
    'setMapBoundaries',
    'getMarkersFrames',
  ],
});

export default codegenNativeComponent<NativeProps>(
  'RNMapsMapView'
) as ComponentType;
