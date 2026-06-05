import { Animated } from 'react-native';
import type { MarkerProps } from './types';

// M7 web stub: renders nothing (the web MapView is a placeholder). Keeps the
// `__MAP_MARKER` sentinel + `Marker.Animated` so the public API matches native.
export type MarkerComponentType = ((props: MarkerProps) => null) & {
  __MAP_MARKER: true;
  Animated: ReturnType<typeof Animated.createAnimatedComponent>;
};

export const Marker = function Marker(_props: MarkerProps) {
  return null;
} as MarkerComponentType;

Marker.__MAP_MARKER = true;
Marker.Animated = Animated.createAnimatedComponent(
  Marker
) as MarkerComponentType['Animated'];

export default Marker;
export type { MarkerProps as MapMarkerProps };
