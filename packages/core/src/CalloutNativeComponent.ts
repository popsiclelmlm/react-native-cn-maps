import {
  codegenNativeComponent,
  type CodegenTypes,
  type HostComponent,
  type ViewProps,
} from 'react-native';

// Callout is a child host component of the marker. Its React subtree renders
// offscreen and becomes the marker's info-window content. The
// press payload is empty — the JS facade fills the RNM `{ action }` shape.
export interface NativeProps extends ViewProps {
  // tooltip = no system frame around the content (pure custom bubble).
  tooltip?: CodegenTypes.WithDefault<boolean, false>;

  // BubblingEventHandler, not Direct: iOS's BaseViewConfig already registers
  // `topPress` as a bubbling event, so a direct registration throws
  // "Event cannot be both direct and bubbling: topPress". (Android has no core
  // topPress, so bubbling is safe there too.)
  onPress?: CodegenTypes.BubblingEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsCallout'
) as HostComponent<NativeProps>;
