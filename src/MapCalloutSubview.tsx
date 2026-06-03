import { useWarnNotImplemented } from './_warnings';
import type { CalloutSubviewProps } from './types';

export type CalloutSubviewComponent = ((props: CalloutSubviewProps) => null) & {
  __MAP_CALLOUT_SUBVIEW: true;
};

export const CalloutSubview: CalloutSubviewComponent = function CalloutSubview(
  _props: CalloutSubviewProps
) {
  useWarnNotImplemented('CalloutSubview');
  return null;
} as CalloutSubviewComponent;

CalloutSubview.__MAP_CALLOUT_SUBVIEW = true;

export default CalloutSubview;
export type { CalloutSubviewProps as MapCalloutSubviewProps };
