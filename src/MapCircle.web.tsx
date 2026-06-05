import type { CircleProps } from './types';

// M7 web stub.
export type CircleComponentType = ((props: CircleProps) => null) & {
  __MAP_CIRCLE: true;
};

export const Circle = function Circle(_props: CircleProps) {
  return null;
} as CircleComponentType;

Circle.__MAP_CIRCLE = true;

export default Circle;
export type { CircleProps as MapCircleProps };
