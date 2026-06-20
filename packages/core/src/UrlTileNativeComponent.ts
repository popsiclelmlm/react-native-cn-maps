import {
  codegenNativeComponent,
  type CodegenTypes,
  type HostComponent,
  type ViewProps,
} from 'react-native';

// Child host component of the map. A raster tile layer driven by a URL
// template containing {x}/{y}/{z} placeholders. Tiles have no coordinates, so no
// coordinate-system conversion applies — only zoom range / caching / styling.
export interface NativeProps extends ViewProps {
  urlTemplate?: string;
  // WMS mode: when true, native substitutes the tile's EPSG:3857 bbox
  // ({minX}/{minY}/{maxX}/{maxY}/{width}/{height}) instead of {x}/{y}/{z}.
  wms?: CodegenTypes.WithDefault<boolean, false>;
  minimumZ?: CodegenTypes.WithDefault<CodegenTypes.Int32, 0>;
  maximumZ?: CodegenTypes.WithDefault<CodegenTypes.Int32, 25>;
  maximumNativeZ?: CodegenTypes.WithDefault<CodegenTypes.Int32, 25>;
  tileSize?: CodegenTypes.WithDefault<CodegenTypes.Int32, 256>;
  doubleTileSize?: CodegenTypes.WithDefault<boolean, false>;
  flipY?: CodegenTypes.WithDefault<boolean, false>;
  opacity?: CodegenTypes.WithDefault<CodegenTypes.Double, 1>;
  overlayZIndex?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  offlineMode?: CodegenTypes.WithDefault<boolean, false>;
  tileCachePath?: string;
  tileCacheMaxAge?: CodegenTypes.WithDefault<CodegenTypes.Int32, 0>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsUrlTile'
) as HostComponent<NativeProps>;
