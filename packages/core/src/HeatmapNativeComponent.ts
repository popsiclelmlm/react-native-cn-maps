// codegenNativeComponent 在 RNOH 的 react-native 重定向入口(0.72)未导出，从深路径默认导入（0.72/0.85 都有，三端通用）。
// eslint-disable-next-line @react-native/no-deep-imports
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import { type HostComponent, type ViewProps } from 'react-native';
import type { Double, Int32, WithDefault } from './codegen-types';

// Child host component of the map. A heatmap rendered as a tile overlay
// from a weighted point set. `points` and `gradient` cross the boundary as JSON
// strings (parsed natively); coordinates are converted to the provider system in
// the JS facade.
export interface NativeProps extends ViewProps {
  points?: string;
  radius?: WithDefault<Int32, 20>;
  opacity?: WithDefault<Double, 0.6>;
  gradient?: string;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsHeatmap'
) as HostComponent<NativeProps>;
