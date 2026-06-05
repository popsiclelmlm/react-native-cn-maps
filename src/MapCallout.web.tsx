import type { CalloutProps } from './types';

// M7 web stub.
export type CalloutComponentType = ((props: CalloutProps) => null) & {
  __MAP_CALLOUT: true;
};

export const Callout = function Callout(_props: CalloutProps) {
  return null;
} as CalloutComponentType;

Callout.__MAP_CALLOUT = true;

export default Callout;
export type { CalloutProps as MapCalloutProps };
