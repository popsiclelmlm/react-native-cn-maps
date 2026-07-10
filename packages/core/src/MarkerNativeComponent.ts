// codegenNativeCommands / codegenNativeComponent 在 RNOH 的 react-native 重定向入口(0.72)未导出，
// 从深路径默认导入：该文件 0.72/0.85 都有，其内部相对依赖会被 RNOH 重定向到 harmony 实现，
// 且 codegen 仅按本地名识别——三端通用。
// eslint-disable-next-line @react-native/no-deep-imports
import codegenNativeCommands from 'react-native/Libraries/Utilities/codegenNativeCommands';
// eslint-disable-next-line @react-native/no-deep-imports
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import { type HostComponent, type ViewProps } from 'react-native';
import type {
  BubblingEventHandler,
  DirectEventHandler,
  Double,
  Int32,
  WithDefault,
} from './codegen-types';

// onPress carries the marker's own coordinate (in the provider/gcj02 system); the
// JS facade rebuilds the RNM `{ coordinate, identifier }` shape on the way out.
export type NativeMarkerPressEvent = Readonly<{
  coordinate: Readonly<{
    latitude: Double;
    longitude: Double;
  }>;
}>;

// Simple {x,y} struct, codegen-friendly (same shape MapView already uses).
export type NativeMarkerPoint = Readonly<{
  x: Double;
  y: Double;
}>;

// Full Marker surface: position + static appearance (image, anchor, centerOffset,
// calloutAnchor, opacity, rotation, flat, overlayZIndex), custom React content
// (rasterized into the icon), drag/select events, and ref commands.
export interface NativeProps extends ViewProps {
  identifier?: string;
  latitude?: WithDefault<Double, 0>;
  longitude?: WithDefault<Double, 0>;
  title?: string;
  description?: string;
  pinColor?: string;
  draggable?: WithDefault<boolean, false>;

  // Appearance (PR-2). `image` is the JS-resolved asset uri (resolveAssetSource).
  // anchor/centerOffset/calloutAnchor map to whichever positioning hook each SDK
  // exposes (anchor → Android marker anchor; centerOffset/calloutAnchor → iOS
  // annotation-view offsets); the off-platform ones are best-effort ignored.
  image?: string;
  anchor?: NativeMarkerPoint;
  centerOffset?: NativeMarkerPoint;
  calloutAnchor?: NativeMarkerPoint;
  opacity?: WithDefault<Double, 1>;
  rotation?: WithDefault<Double, 0>;
  flat?: WithDefault<boolean, false>;
  overlayZIndex?: WithDefault<Double, 0>;

  // Custom React content (PR-3). When the marker has children they render
  // offscreen and are rasterized into the marker icon. `tracksViewChanges`
  // re-rasterizes on every layout (RNM default true — costly with many markers);
  // `tracksInfoWindowChanges` is accepted for parity (system callout only here).
  tracksViewChanges?: WithDefault<boolean, true>;
  tracksInfoWindowChanges?: WithDefault<boolean, false>;

  // Interaction (PR-4). All carry the marker's `{ coordinate }` (drag events
  // report the new position); the JS facade re-attaches `identifier` and converts
  // the coordinate back out of the provider system.
  // `onPress` collides with iOS's built-in bubbling `topPress` (BaseViewConfig
  // registers it globally), so it must be bubbling too — a Direct handler throws
  // "Event cannot be both direct and bubbling: topPress" (same as onSelect below).
  onPress?: BubblingEventHandler<NativeMarkerPressEvent>;
  // `onSelect` collides with React Native's built-in bubbling `topSelect`
  // (BaseViewConfig registers it globally with bubbled name `onSelect`), so it
  // must be declared bubbling — a Direct handler triggers the runtime invariant
  // "Event cannot be both direct and bubbling: topSelect".
  onSelect?: BubblingEventHandler<NativeMarkerPressEvent>;
  onDeselect?: DirectEventHandler<NativeMarkerPressEvent>;
  onCalloutPress?: DirectEventHandler<NativeMarkerPressEvent>;
  onDragStart?: DirectEventHandler<NativeMarkerPressEvent>;
  onDrag?: DirectEventHandler<NativeMarkerPressEvent>;
  onDragEnd?: DirectEventHandler<NativeMarkerPressEvent>;
}

type ComponentType = HostComponent<NativeProps>;

interface NativeCommands {
  showCallout: (viewRef: React.ElementRef<ComponentType>) => void;
  hideCallout: (viewRef: React.ElementRef<ComponentType>) => void;
  redrawCallout: (viewRef: React.ElementRef<ComponentType>) => void;
  redraw: (viewRef: React.ElementRef<ComponentType>) => void;
  animateMarkerToCoordinate: (
    viewRef: React.ElementRef<ComponentType>,
    latitude: Double,
    longitude: Double,
    duration: Int32
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
