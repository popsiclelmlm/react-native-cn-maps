import { Animated } from 'react-native';
import type { MarkerProps } from './types';

export type MarkerComponent = ((props: MarkerProps) => null) & {
  __MAP_MARKER: true;
  Animated: ReturnType<typeof Animated.createAnimatedComponent>;
};

export const Marker: MarkerComponent = function Marker(_props: MarkerProps) {
  return null;
} as MarkerComponent;

Marker.__MAP_MARKER = true;

// RNM parity: `Marker.Animated`, also re-exported as `MarkerAnimated`.
Marker.Animated = Animated.createAnimatedComponent(
  Marker
) as MarkerComponent['Animated'];

export default Marker;
export type { MarkerProps as MapMarkerProps };
