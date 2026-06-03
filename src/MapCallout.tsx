import { useWarnNotImplemented } from './_warnings';
import type { CalloutProps } from './types';

export type CalloutComponent = ((props: CalloutProps) => null) & {
  __MAP_CALLOUT: true;
};

export const Callout: CalloutComponent = function Callout(
  _props: CalloutProps
) {
  useWarnNotImplemented('Callout');
  return null;
} as CalloutComponent;

Callout.__MAP_CALLOUT = true;

export default Callout;
export type { CalloutProps as MapCalloutProps };
