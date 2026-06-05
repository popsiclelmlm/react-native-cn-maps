import { Animated } from 'react-native';
import { useWarnNotImplemented } from './_warnings';
import type { OverlayProps } from './types';

export type OverlayComponent = ((props: OverlayProps) => null) & {
  __MAP_OVERLAY: true;
  Animated: ReturnType<typeof Animated.createAnimatedComponent>;
};

export const Overlay: OverlayComponent = function Overlay(
  _props: OverlayProps
) {
  useWarnNotImplemented('Overlay');
  return null;
} as OverlayComponent;

Overlay.__MAP_OVERLAY = true;

// RNM parity: `Overlay.Animated`, also re-exported as `OverlayAnimated`.
Overlay.Animated = Animated.createAnimatedComponent(
  Overlay
) as OverlayComponent['Animated'];

export default Overlay;
export type { OverlayProps as MapOverlayProps };
