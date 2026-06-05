import {
  codegenNativeComponent,
  type CodegenTypes,
  type HostComponent,
  type ViewProps,
} from 'react-native';

// onPress carries the marker's own coordinate (in the provider/gcj02 system); the
// JS facade rebuilds the RNM `{ coordinate, identifier }` shape on the way out.
export type NativeMarkerPressEvent = Readonly<{
  coordinate: Readonly<{
    latitude: CodegenTypes.Double;
    longitude: CodegenTypes.Double;
  }>;
}>;

// M3 PR-1 lands the minimal prop set proven against the M2 marker behavior; the
// richer appearance / drag / command surface (image, anchor, zIndex, drag
// events, commands…) arrives in later M3 PRs.
export interface NativeProps extends ViewProps {
  identifier?: string;
  latitude?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  longitude?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  title?: string;
  description?: string;
  pinColor?: string;
  draggable?: CodegenTypes.WithDefault<boolean, false>;

  onPress?: CodegenTypes.DirectEventHandler<NativeMarkerPressEvent>;
}

export default codegenNativeComponent<NativeProps>(
  'RNMapsMarker'
) as HostComponent<NativeProps>;
