import {
  codegenNativeComponent,
  type CodegenTypes,
  type HostComponent,
  type ViewProps,
} from 'react-native';

// Child host component of the map (M17). A heatmap rendered as a tile overlay
// from a weighted point set. `points` and `gradient` cross the boundary as JSON
// strings (parsed natively); coordinates are converted to the provider system in
// the JS facade.
export interface NativeProps extends ViewProps {
  points?: string;
  radius?: CodegenTypes.WithDefault<CodegenTypes.Int32, 20>;
  opacity?: CodegenTypes.WithDefault<CodegenTypes.Double, 0.6>;
  gradient?: string;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsHeatmap'
) as HostComponent<NativeProps>;
