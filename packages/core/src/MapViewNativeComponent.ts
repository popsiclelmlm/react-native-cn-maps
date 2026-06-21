import {
  codegenNativeCommands,
  codegenNativeComponent,
  type ColorValue,
  type CodegenTypes,
  type HostComponent,
  type ViewProps,
} from 'react-native';

export type NativeRegion = Readonly<{
  latitude: CodegenTypes.Double;
  longitude: CodegenTypes.Double;
  latitudeDelta: CodegenTypes.Double;
  longitudeDelta: CodegenTypes.Double;
}>;

// `center` is flattened to latitude/longitude so the struct stays codegen
// friendly (no nested object props). JS rebuilds the RNM `{ center: LatLng }`
// shape on the way in/out.
export type NativeCamera = Readonly<{
  latitude: CodegenTypes.Double;
  longitude: CodegenTypes.Double;
  heading: CodegenTypes.Double;
  pitch: CodegenTypes.Double;
  zoom: CodegenTypes.Double;
  altitude: CodegenTypes.Double;
}>;

export type NativeEdgePadding = Readonly<{
  top: CodegenTypes.Double;
  right: CodegenTypes.Double;
  bottom: CodegenTypes.Double;
  left: CodegenTypes.Double;
}>;

export type NativeRegionChangeEvent = Readonly<{
  region: Readonly<{
    latitude: CodegenTypes.Double;
    longitude: CodegenTypes.Double;
    latitudeDelta: CodegenTypes.Double;
    longitudeDelta: CodegenTypes.Double;
  }>;
  isGesture?: boolean;
}>;

// Shared by onPress / onLongPress / onDoublePress / onPanDrag.
export type NativeMapPressEvent = Readonly<{
  coordinate: Readonly<{
    latitude: CodegenTypes.Double;
    longitude: CodegenTypes.Double;
  }>;
  position: Readonly<{
    x: CodegenTypes.Double;
    y: CodegenTypes.Double;
  }>;
}>;

export type NativePoiClickEvent = Readonly<{
  placeId?: string;
  name?: string;
  coordinate: Readonly<{
    latitude: CodegenTypes.Double;
    longitude: CodegenTypes.Double;
  }>;
  position?: Readonly<{
    x: CodegenTypes.Double;
    y: CodegenTypes.Double;
  }>;
}>;

export type NativeUserLocationChangeEvent = Readonly<{
  coordinate?: Readonly<{
    latitude: CodegenTypes.Double;
    longitude: CodegenTypes.Double;
    altitude: CodegenTypes.Double;
    accuracy: CodegenTypes.Double;
    speed: CodegenTypes.Double;
    heading: CodegenTypes.Double;
    isFromMockProvider?: boolean;
  }>;
}>;

export interface NativeProps extends ViewProps {
  provider?: CodegenTypes.WithDefault<string, 'amap'>;
  coordinateSystem?: CodegenTypes.WithDefault<string, 'gcj02'>;

  // Region / camera
  initialRegion?: NativeRegion;
  region?: NativeRegion;
  initialCamera?: NativeCamera;
  camera?: NativeCamera;

  // Appearance
  mapType?: CodegenTypes.WithDefault<string, 'standard'>;
  customMapStyle?: string; // JSON-stringified MapStyleElement[] (see JS facade)
  userInterfaceStyle?: CodegenTypes.WithDefault<string, 'system'>;
  tintColor?: ColorValue;
  mapPadding?: NativeEdgePadding;
  kmlSrc?: string;

  // Zoom
  minZoomLevel?: CodegenTypes.WithDefault<CodegenTypes.Double, 3>;
  maxZoomLevel?: CodegenTypes.WithDefault<CodegenTypes.Double, 20>;

  // Gesture toggles
  zoomEnabled?: CodegenTypes.WithDefault<boolean, true>;
  zoomTapEnabled?: CodegenTypes.WithDefault<boolean, true>;
  zoomControlEnabled?: CodegenTypes.WithDefault<boolean, false>;
  scrollEnabled?: CodegenTypes.WithDefault<boolean, true>;
  scrollDuringRotateOrZoomEnabled?: CodegenTypes.WithDefault<boolean, true>;
  rotateEnabled?: CodegenTypes.WithDefault<boolean, true>;
  pitchEnabled?: CodegenTypes.WithDefault<boolean, true>;

  // Display toggles
  showsUserLocation?: CodegenTypes.WithDefault<boolean, false>;
  showsMyLocationButton?: CodegenTypes.WithDefault<boolean, true>;
  showsCompass?: CodegenTypes.WithDefault<boolean, true>;
  showsScale?: CodegenTypes.WithDefault<boolean, false>;
  showsTraffic?: CodegenTypes.WithDefault<boolean, false>;
  showsBuildings?: CodegenTypes.WithDefault<boolean, true>;
  showsIndoors?: CodegenTypes.WithDefault<boolean, true>;
  showsIndoorLevelPicker?: CodegenTypes.WithDefault<boolean, false>;
  showsPointsOfInterest?: CodegenTypes.WithDefault<boolean, true>;

  // Loading state
  loadingEnabled?: CodegenTypes.WithDefault<boolean, false>;
  loadingIndicatorColor?: ColorValue;
  loadingBackgroundColor?: ColorValue;

  // Android-only
  toolbarEnabled?: CodegenTypes.WithDefault<boolean, true>;
  liteMode?: CodegenTypes.WithDefault<boolean, false>;
  cacheEnabled?: CodegenTypes.WithDefault<boolean, false>;

  // Region / camera events
  onRegionChange?: CodegenTypes.DirectEventHandler<NativeRegionChangeEvent>;
  onRegionChangeComplete?: CodegenTypes.DirectEventHandler<NativeRegionChangeEvent>;

  // Lifecycle
  onMapReady?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
  onMapLoaded?: CodegenTypes.DirectEventHandler<Readonly<{}>>;

  // Gestures
  // onPress is Bubbling (not Direct): iOS core registers `topPress` as bubbling,
  // so a direct registration throws "Event cannot be both direct and bubbling".
  onPress?: CodegenTypes.BubblingEventHandler<NativeMapPressEvent>;
  onLongPress?: CodegenTypes.DirectEventHandler<NativeMapPressEvent>;
  onDoublePress?: CodegenTypes.DirectEventHandler<NativeMapPressEvent>;
  onPanDrag?: CodegenTypes.DirectEventHandler<NativeMapPressEvent>;
  onPoiClick?: CodegenTypes.DirectEventHandler<NativePoiClickEvent>;

  // User location
  onUserLocationChange?: CodegenTypes.DirectEventHandler<NativeUserLocationChangeEvent>;

  // Result channel for Promise-returning ref methods. Native serializes the
  // result to JSON keyed by the JS-generated request id (RNM's Fabric pattern).
  onCommandResult?: CodegenTypes.DirectEventHandler<NativeCommandResultEvent>;
}

export type NativeCommandResultEvent = Readonly<{
  id: CodegenTypes.Int32;
  data: string;
}>;

type ComponentType = HostComponent<NativeProps>;

// Geometry args that codegen commands can't pass as objects cross as JSON
// strings (coordinates, edgePadding, marker id lists).
interface NativeCommands {
  animateToRegion: (
    viewRef: React.ElementRef<ComponentType>,
    latitude: CodegenTypes.Double,
    longitude: CodegenTypes.Double,
    latitudeDelta: CodegenTypes.Double,
    longitudeDelta: CodegenTypes.Double,
    duration: CodegenTypes.Int32
  ) => void;
  animateCamera: (
    viewRef: React.ElementRef<ComponentType>,
    latitude: CodegenTypes.Double,
    longitude: CodegenTypes.Double,
    heading: CodegenTypes.Double,
    pitch: CodegenTypes.Double,
    zoom: CodegenTypes.Double,
    duration: CodegenTypes.Int32
  ) => void;
  setCamera: (
    viewRef: React.ElementRef<ComponentType>,
    latitude: CodegenTypes.Double,
    longitude: CodegenTypes.Double,
    heading: CodegenTypes.Double,
    pitch: CodegenTypes.Double,
    zoom: CodegenTypes.Double
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
    requestId: CodegenTypes.Int32
  ) => void;
  getMapBoundaries: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: CodegenTypes.Int32
  ) => void;
  pointForCoordinate: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: CodegenTypes.Int32,
    latitude: CodegenTypes.Double,
    longitude: CodegenTypes.Double
  ) => void;
  coordinateForPoint: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: CodegenTypes.Int32,
    x: CodegenTypes.Double,
    y: CodegenTypes.Double
  ) => void;
  addressForCoordinate: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: CodegenTypes.Int32,
    latitude: CodegenTypes.Double,
    longitude: CodegenTypes.Double
  ) => void;
  takeSnapshot: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: CodegenTypes.Int32,
    width: CodegenTypes.Int32,
    height: CodegenTypes.Int32,
    format: string,
    quality: CodegenTypes.Double,
    result: string
  ) => void;
  setMapBoundaries: (
    viewRef: React.ElementRef<ComponentType>,
    neLatitude: CodegenTypes.Double,
    neLongitude: CodegenTypes.Double,
    swLatitude: CodegenTypes.Double,
    swLongitude: CodegenTypes.Double
  ) => void;
  getMarkersFrames: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: CodegenTypes.Int32,
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
