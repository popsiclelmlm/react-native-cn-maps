import {
  codegenNativeComponent,
  type CodegenTypes,
  type ColorValue,
  type HostComponent,
  type ViewProps,
} from 'react-native';

export type NativeLatLng = Readonly<{
  latitude: CodegenTypes.Double;
  longitude: CodegenTypes.Double;
}>;

// Child host component of the map (M5). Coordinates arrive already converted to
// the provider system (gcj02) by the JS facade. `lineDashPattern` is passed as a
// JSON string to sidestep codegen number-array limitations.
export interface NativeProps extends ViewProps {
  coordinates?: ReadonlyArray<NativeLatLng>;
  strokeColor?: ColorValue;
  strokeWidth?: CodegenTypes.WithDefault<CodegenTypes.Double, 1>;
  lineDashPattern?: string;
  geodesic?: CodegenTypes.WithDefault<boolean, false>;
  zIndex?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  tappable?: CodegenTypes.WithDefault<boolean, false>;

  onPress?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsPolyline'
) as HostComponent<NativeProps>;
