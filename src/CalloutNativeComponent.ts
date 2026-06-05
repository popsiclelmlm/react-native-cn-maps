import {
  codegenNativeComponent,
  type CodegenTypes,
  type HostComponent,
  type ViewProps,
} from 'react-native';

// Callout is a child host component of the marker. Its React subtree renders
// offscreen and becomes the marker's info-window content (see M4 design). The
// press payload is empty — the JS facade fills the RNM `{ action }` shape.
export interface NativeProps extends ViewProps {
  // tooltip = no system frame around the content (pure custom bubble).
  tooltip?: CodegenTypes.WithDefault<boolean, false>;

  onPress?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsCallout'
) as HostComponent<NativeProps>;
