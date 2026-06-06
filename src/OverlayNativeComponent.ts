import {
  codegenNativeComponent,
  type CodegenTypes,
  type HostComponent,
  type ViewProps,
} from 'react-native';

// Child host component of the map (M12). An image "ground overlay" placed by a
// geographic bounding box. The JS facade resolves `image` to a uri and converts
// the RNM `bounds` (two corners) into normalized SW/NE corners in the provider
// (gcj02) coordinate system.
export interface NativeProps extends ViewProps {
  image?: string;
  swLatitude?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  swLongitude?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  neLatitude?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  neLongitude?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  bearing?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  opacity?: CodegenTypes.WithDefault<CodegenTypes.Double, 1>;
  overlayZIndex?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;

  onPress?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsOverlay'
) as HostComponent<NativeProps>;
