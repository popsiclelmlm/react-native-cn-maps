// codegenNativeComponent 在 RNOH 的 react-native 重定向入口(0.72)未导出，从深路径默认导入（0.72/0.85 都有，三端通用）。
// eslint-disable-next-line @react-native/no-deep-imports
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import { type HostComponent, type ViewProps } from 'react-native';
import type { Double, Int32, WithDefault } from './codegen-types';

// Child host component of the map. A raster tile layer read from local
// files, driven by a path template containing {x}/{y}/{z} placeholders.
export interface NativeProps extends ViewProps {
  pathTemplate?: string;
  tileSize?: WithDefault<Int32, 256>;
  useAssets?: WithDefault<boolean, false>;
  overlayZIndex?: WithDefault<Double, 0>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsLocalTile'
) as HostComponent<NativeProps>;
