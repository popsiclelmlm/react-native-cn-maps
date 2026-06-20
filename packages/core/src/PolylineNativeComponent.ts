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

// Child host component of the map. Coordinates arrive already converted to
// the provider system (gcj02) by the JS facade. `lineDashPattern` is passed as a
// JSON string to sidestep codegen number-array limitations.
export interface NativeProps extends ViewProps {
  coordinates?: ReadonlyArray<NativeLatLng>;
  strokeColor?: ColorValue;
  // Gradient stroke colors: a JSON string array of CSS color strings,
  // parsed natively (sidesteps codegen's lack of ColorValue-array support).
  strokeColors?: string;
  strokeWidth?: CodegenTypes.WithDefault<CodegenTypes.Double, 1>;
  lineDashPattern?: string;
  lineCap?: string;
  lineJoin?: string;
  miterLimit?: CodegenTypes.WithDefault<CodegenTypes.Double, 10>;
  geodesic?: CodegenTypes.WithDefault<boolean, false>;
  overlayZIndex?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  tappable?: CodegenTypes.WithDefault<boolean, false>;

  // Bubbling (not Direct): iOS core registers `topPress` as bubbling — a direct
  // registration throws "Event cannot be both direct and bubbling: topPress".
  onPress?: CodegenTypes.BubblingEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsPolyline'
) as HostComponent<NativeProps>;
