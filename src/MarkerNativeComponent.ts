import {
  codegenNativeCommands,
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

// Simple {x,y} struct, codegen-friendly (same shape MapView already uses).
export type NativeMarkerPoint = Readonly<{
  x: CodegenTypes.Double;
  y: CodegenTypes.Double;
}>;

// M3 PR-1 landed the minimal prop set; PR-2 adds the static-appearance surface
// (image, anchor, centerOffset, calloutAnchor, opacity, rotation, flat, overlayZIndex).
// Custom React content, drag/select events and ref commands arrive in PR-3/PR-4.
export interface NativeProps extends ViewProps {
  identifier?: string;
  latitude?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  longitude?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  title?: string;
  description?: string;
  pinColor?: string;
  draggable?: CodegenTypes.WithDefault<boolean, false>;

  // Appearance (PR-2). `image` is the JS-resolved asset uri (resolveAssetSource).
  // anchor/centerOffset/calloutAnchor map to whichever positioning hook each SDK
  // exposes (anchor → Android marker anchor; centerOffset/calloutAnchor → iOS
  // annotation-view offsets); the off-platform ones are best-effort ignored.
  image?: string;
  anchor?: NativeMarkerPoint;
  centerOffset?: NativeMarkerPoint;
  calloutAnchor?: NativeMarkerPoint;
  opacity?: CodegenTypes.WithDefault<CodegenTypes.Double, 1>;
  rotation?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  flat?: CodegenTypes.WithDefault<boolean, false>;
  overlayZIndex?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;

  // Custom React content (PR-3). When the marker has children they render
  // offscreen and are rasterized into the marker icon. `tracksViewChanges`
  // re-rasterizes on every layout (RNM default true — costly with many markers);
  // `tracksInfoWindowChanges` is accepted for parity (system callout only here).
  tracksViewChanges?: CodegenTypes.WithDefault<boolean, true>;
  tracksInfoWindowChanges?: CodegenTypes.WithDefault<boolean, false>;

  // Interaction (PR-4). All carry the marker's `{ coordinate }` (drag events
  // report the new position); the JS facade re-attaches `identifier` and converts
  // the coordinate back out of the provider system.
  onPress?: CodegenTypes.DirectEventHandler<NativeMarkerPressEvent>;
  // `onSelect` collides with React Native's built-in bubbling `topSelect`
  // (BaseViewConfig registers it globally with bubbled name `onSelect`), so it
  // must be declared bubbling — a Direct handler triggers the runtime invariant
  // "Event cannot be both direct and bubbling: topSelect".
  onSelect?: CodegenTypes.BubblingEventHandler<NativeMarkerPressEvent>;
  onDeselect?: CodegenTypes.DirectEventHandler<NativeMarkerPressEvent>;
  onCalloutPress?: CodegenTypes.DirectEventHandler<NativeMarkerPressEvent>;
  onDragStart?: CodegenTypes.DirectEventHandler<NativeMarkerPressEvent>;
  onDrag?: CodegenTypes.DirectEventHandler<NativeMarkerPressEvent>;
  onDragEnd?: CodegenTypes.DirectEventHandler<NativeMarkerPressEvent>;
}

type ComponentType = HostComponent<NativeProps>;

interface NativeCommands {
  showCallout: (viewRef: React.ElementRef<ComponentType>) => void;
  hideCallout: (viewRef: React.ElementRef<ComponentType>) => void;
  redrawCallout: (viewRef: React.ElementRef<ComponentType>) => void;
  redraw: (viewRef: React.ElementRef<ComponentType>) => void;
  animateMarkerToCoordinate: (
    viewRef: React.ElementRef<ComponentType>,
    latitude: CodegenTypes.Double,
    longitude: CodegenTypes.Double,
    duration: CodegenTypes.Int32
  ) => void;
}

export const Commands: NativeCommands = codegenNativeCommands<NativeCommands>({
  supportedCommands: [
    'showCallout',
    'hideCallout',
    'redrawCallout',
    'redraw',
    'animateMarkerToCoordinate',
  ],
});

export default codegenNativeComponent<NativeProps>(
  'RNMapsMarker'
) as ComponentType;
