// codegenNativeComponent 在 RNOH 的 react-native 重定向入口(0.72)未导出，从深路径默认导入（0.72/0.85 都有，三端通用）。
// eslint-disable-next-line @react-native/no-deep-imports
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import { type HostComponent, type ViewProps } from 'react-native';
import type {
  BubblingEventHandler,
  Double,
  WithDefault,
} from './codegen-types';

// Child host component of the map. An image "ground overlay" placed by a
// geographic bounding box. The JS facade resolves `image` to a uri and converts
// the RNM `bounds` (two corners) into normalized SW/NE corners in the provider
// (gcj02) coordinate system.
export interface NativeProps extends ViewProps {
  image?: string;
  swLatitude?: WithDefault<Double, 0>;
  swLongitude?: WithDefault<Double, 0>;
  neLatitude?: WithDefault<Double, 0>;
  neLongitude?: WithDefault<Double, 0>;
  bearing?: WithDefault<Double, 0>;
  opacity?: WithDefault<Double, 1>;
  overlayZIndex?: WithDefault<Double, 0>;

  // Bubbling (not Direct): iOS core registers `topPress` as bubbling — a direct
  // registration throws "Event cannot be both direct and bubbling: topPress".
  onPress?: BubblingEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsOverlay'
) as HostComponent<NativeProps>;
