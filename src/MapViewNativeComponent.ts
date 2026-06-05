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

export type NativeCoordinate = Readonly<{
  latitude: CodegenTypes.Double;
  longitude: CodegenTypes.Double;
}>;

export type NativePoint = Readonly<{
  x: CodegenTypes.Double;
  y: CodegenTypes.Double;
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
  coordinate: NativeCoordinate;
  position: NativePoint;
}>;

export type NativePoiClickEvent = Readonly<{
  placeId?: string;
  name?: string;
  coordinate: NativeCoordinate;
  position?: NativePoint;
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
  onPress?: CodegenTypes.DirectEventHandler<NativeMapPressEvent>;
  onLongPress?: CodegenTypes.DirectEventHandler<NativeMapPressEvent>;
  onDoublePress?: CodegenTypes.DirectEventHandler<NativeMapPressEvent>;
  onPanDrag?: CodegenTypes.DirectEventHandler<NativeMapPressEvent>;
  onPoiClick?: CodegenTypes.DirectEventHandler<NativePoiClickEvent>;

  // User location
  onUserLocationChange?: CodegenTypes.DirectEventHandler<NativeUserLocationChangeEvent>;
}

type ComponentType = HostComponent<NativeProps>;

interface NativeCommands {
  animateToRegion: (
    viewRef: React.ElementRef<ComponentType>,
    latitude: CodegenTypes.Double,
    longitude: CodegenTypes.Double,
    latitudeDelta: CodegenTypes.Double,
    longitudeDelta: CodegenTypes.Double,
    duration: CodegenTypes.Int32
  ) => void;
}

export const Commands: NativeCommands = codegenNativeCommands<NativeCommands>({
  supportedCommands: ['animateToRegion'],
});

export default codegenNativeComponent<NativeProps>(
  'RNMapsMapView'
) as ComponentType;
