// codegenNativeComponent 在 RNOH 的 react-native 重定向入口(0.72)未导出，从深路径默认导入（0.72/0.85 都有，三端通用）。
// eslint-disable-next-line @react-native/no-deep-imports
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import { type HostComponent, type ViewProps } from 'react-native';
import type { BubblingEventHandler, WithDefault } from './codegen-types';

// Callout is a child host component of the marker. Its React subtree renders
// offscreen and becomes the marker's info-window content. The
// press payload is empty — the JS facade fills the RNM `{ action }` shape.
export interface NativeProps extends ViewProps {
  // tooltip = no system frame around the content (pure custom bubble).
  tooltip?: WithDefault<boolean, false>;

  // BubblingEventHandler, not Direct: iOS's BaseViewConfig already registers
  // `topPress` as a bubbling event, so a direct registration throws
  // "Event cannot be both direct and bubbling: topPress". (Android has no core
  // topPress, so bubbling is safe there too.)
  onPress?: BubblingEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsCallout'
) as HostComponent<NativeProps>;
