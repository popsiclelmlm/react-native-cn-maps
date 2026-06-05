import React from 'react';
import NativeCallout from './CalloutNativeComponent';
import type { CalloutPressEvent, CalloutProps } from './types';

/**
 * `<Callout>` is a child host component of `<Marker>`. Its React subtree renders
 * offscreen and is shown as the marker's info window (iOS: rasterized image above
 * the annotation; Android: AMap InfoWindowAdapter). Whole-callout `onPress` is
 * routed; per-`CalloutSubview` taps are a documented M4 limitation.
 */
function CalloutComponent(props: CalloutProps) {
  // `alphaHitTest` and other ViewProps beyond `style` have no effect on the
  // offscreen-rasterized callout, so only `style` (which sizes it) is forwarded.
  const { tooltip, onPress, children, style } = props;

  return (
    <NativeCallout
      style={style}
      tooltip={tooltip}
      onPress={
        onPress
          ? () =>
              onPress({
                nativeEvent: { action: 'callout-press' },
              } satisfies CalloutPressEvent)
          : undefined
      }
    >
      {children}
    </NativeCallout>
  );
}

export type CalloutComponentType = ((
  props: CalloutProps
) => React.ReactElement) & {
  __MAP_CALLOUT: true;
};

export const Callout = CalloutComponent as unknown as CalloutComponentType;

// Sentinel kept for parity with the M1 stub.
Callout.__MAP_CALLOUT = true;

export default Callout;
export type { CalloutProps as MapCalloutProps };
