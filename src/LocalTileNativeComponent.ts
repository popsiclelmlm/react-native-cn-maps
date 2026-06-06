import {
  codegenNativeComponent,
  type CodegenTypes,
  type HostComponent,
  type ViewProps,
} from 'react-native';

// Child host component of the map. A raster tile layer read from local
// files, driven by a path template containing {x}/{y}/{z} placeholders.
export interface NativeProps extends ViewProps {
  pathTemplate?: string;
  tileSize?: CodegenTypes.WithDefault<CodegenTypes.Int32, 256>;
  useAssets?: CodegenTypes.WithDefault<boolean, false>;
  overlayZIndex?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsLocalTile'
) as HostComponent<NativeProps>;
