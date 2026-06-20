import React from 'react';
import { View } from 'react-native';
import type { CalloutSubviewProps } from './types';

/**
 * `<CalloutSubview>` renders its content inside the parent `<Callout>`. Because
 * the callout is shown as a rasterized snapshot (Android InfoWindow) / image
 * (iOS), individual subview taps are NOT independently routed — use the
 * parent `<Callout onPress>` / `<Marker onCalloutPress>` for whole-callout taps.
 * The `onPress` prop is accepted for API parity but is a documented no-op here.
 */
export type CalloutSubviewComponent = ((
  props: CalloutSubviewProps
) => React.ReactElement) & {
  __MAP_CALLOUT_SUBVIEW: true;
};

function CalloutSubviewComp(props: CalloutSubviewProps) {
  // `onPress` is intentionally not wired (see component doc); forward layout only.
  const { children, style } = props;
  return <View style={style}>{children}</View>;
}

export const CalloutSubview =
  CalloutSubviewComp as unknown as CalloutSubviewComponent;

CalloutSubview.__MAP_CALLOUT_SUBVIEW = true;

export default CalloutSubview;
export type { CalloutSubviewProps as MapCalloutSubviewProps };
