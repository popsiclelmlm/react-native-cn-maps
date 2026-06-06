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

// Child host component of the map (M5). `holes` is a JSON string of
// LatLng[][] (provider system) to sidestep codegen nested-array limitations.
export interface NativeProps extends ViewProps {
  coordinates?: ReadonlyArray<NativeLatLng>;
  holes?: string;
  strokeColor?: ColorValue;
  strokeWidth?: CodegenTypes.WithDefault<CodegenTypes.Double, 1>;
  fillColor?: ColorValue;
  lineDashPattern?: string;
  overlayZIndex?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  tappable?: CodegenTypes.WithDefault<boolean, false>;

  // Bubbling (not Direct): iOS core registers `topPress` as bubbling — a direct
  // registration throws "Event cannot be both direct and bubbling: topPress".
  onPress?: CodegenTypes.BubblingEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsPolygon'
) as HostComponent<NativeProps>;
