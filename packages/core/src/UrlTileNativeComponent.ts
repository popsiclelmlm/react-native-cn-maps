// codegenNativeComponent 在 RNOH 的 react-native 重定向入口(0.72)未导出，从深路径默认导入（0.72/0.85 都有，三端通用）。
// eslint-disable-next-line @react-native/no-deep-imports
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import { type HostComponent, type ViewProps } from 'react-native';
import type { Double, Int32, WithDefault } from './codegen-types';

// Child host component of the map. A raster tile layer driven by a URL
// template containing {x}/{y}/{z} placeholders. Tiles have no coordinates, so no
// coordinate-system conversion applies — only zoom range / caching / styling.
export interface NativeProps extends ViewProps {
  urlTemplate?: string;
  // WMS mode: when true, native substitutes the tile's EPSG:3857 bbox
  // ({minX}/{minY}/{maxX}/{maxY}/{width}/{height}) instead of {x}/{y}/{z}.
  wms?: WithDefault<boolean, false>;
  minimumZ?: WithDefault<Int32, 0>;
  maximumZ?: WithDefault<Int32, 25>;
  maximumNativeZ?: WithDefault<Int32, 25>;
  tileSize?: WithDefault<Int32, 256>;
  doubleTileSize?: WithDefault<boolean, false>;
  flipY?: WithDefault<boolean, false>;
  opacity?: WithDefault<Double, 1>;
  overlayZIndex?: WithDefault<Double, 0>;
  offlineMode?: WithDefault<boolean, false>;
  tileCachePath?: string;
  tileCacheMaxAge?: WithDefault<Int32, 0>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsUrlTile'
) as HostComponent<NativeProps>;
