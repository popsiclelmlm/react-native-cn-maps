import {
  codegenNativeCommands,
  codegenNativeComponent,
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

export type NativeMarker = Readonly<{
  identifier: string;
  latitude: CodegenTypes.Double;
  longitude: CodegenTypes.Double;
  title?: string;
  description?: string;
  pinColor?: string;
  draggable?: CodegenTypes.WithDefault<boolean, false>;
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

export type NativeMarkerPressEvent = Readonly<{
  identifier: string;
  coordinate: Readonly<{
    latitude: CodegenTypes.Double;
    longitude: CodegenTypes.Double;
  }>;
}>;

export interface NativeProps extends ViewProps {
  provider?: CodegenTypes.WithDefault<string, 'amap'>;
  coordinateSystem?: CodegenTypes.WithDefault<string, 'gcj02'>;
  initialRegion?: NativeRegion;
  region?: NativeRegion;
  markers?: ReadonlyArray<NativeMarker>;
  showsUserLocation?: CodegenTypes.WithDefault<boolean, false>;
  zoomEnabled?: CodegenTypes.WithDefault<boolean, true>;
  scrollEnabled?: CodegenTypes.WithDefault<boolean, true>;
  rotateEnabled?: CodegenTypes.WithDefault<boolean, true>;
  pitchEnabled?: CodegenTypes.WithDefault<boolean, true>;
  onRegionChange?: CodegenTypes.DirectEventHandler<NativeRegionChangeEvent>;
  onRegionChangeComplete?: CodegenTypes.DirectEventHandler<NativeRegionChangeEvent>;
  onMarkerPress?: CodegenTypes.DirectEventHandler<NativeMarkerPressEvent>;
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
