import { useWarnNotImplemented } from './_warnings';
import type { CircleProps } from './types';

export type CircleComponent = ((props: CircleProps) => null) & {
  __MAP_CIRCLE: true;
};

export const Circle: CircleComponent = function Circle(_props: CircleProps) {
  useWarnNotImplemented('Circle');
  return null;
} as CircleComponent;

Circle.__MAP_CIRCLE = true;

export default Circle;
export type { CircleProps as MapCircleProps };
