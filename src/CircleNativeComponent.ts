import {
  codegenNativeComponent,
  type CodegenTypes,
  type ColorValue,
  type HostComponent,
  type ViewProps,
} from 'react-native';

// Child host component of the map (M5). `center` is flattened to scalars
// (provider system); `radius` is in meters.
export interface NativeProps extends ViewProps {
  latitude?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  longitude?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  radius?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  strokeColor?: ColorValue;
  strokeWidth?: CodegenTypes.WithDefault<CodegenTypes.Double, 1>;
  fillColor?: ColorValue;
  lineDashPattern?: string;
  zIndex?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  tappable?: CodegenTypes.WithDefault<boolean, false>;

  onPress?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsCircle'
) as HostComponent<NativeProps>;
