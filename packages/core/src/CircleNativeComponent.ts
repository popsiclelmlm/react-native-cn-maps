// codegenNativeComponent 在 RNOH 的 react-native 重定向入口(0.72)未导出，从深路径默认导入（0.72/0.85 都有，三端通用）。
// eslint-disable-next-line @react-native/no-deep-imports
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import {
  type ColorValue,
  type HostComponent,
  type ViewProps,
} from 'react-native';
import type {
  BubblingEventHandler,
  Double,
  WithDefault,
} from './codegen-types';

// Child host component of the map. `center` is flattened to scalars
// (provider system); `radius` is in meters.
export interface NativeProps extends ViewProps {
  latitude?: WithDefault<Double, 0>;
  longitude?: WithDefault<Double, 0>;
  radius?: WithDefault<Double, 0>;
  strokeColor?: ColorValue;
  strokeWidth?: WithDefault<Double, 1>;
  fillColor?: ColorValue;
  lineDashPattern?: string;
  overlayZIndex?: WithDefault<Double, 0>;
  tappable?: WithDefault<boolean, false>;

  // Bubbling (not Direct): iOS core registers `topPress` as bubbling — a direct
  // registration throws "Event cannot be both direct and bubbling: topPress".
  onPress?: BubblingEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsCircle'
) as HostComponent<NativeProps>;
