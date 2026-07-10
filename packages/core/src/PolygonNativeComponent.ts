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

export type NativeLatLng = Readonly<{
  latitude: Double;
  longitude: Double;
}>;

// Child host component of the map. `holes` is a JSON string of
// LatLng[][] (provider system) to sidestep codegen nested-array limitations.
export interface NativeProps extends ViewProps {
  coordinates?: ReadonlyArray<NativeLatLng>;
  holes?: string;
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
  'RNMapsPolygon'
) as HostComponent<NativeProps>;
