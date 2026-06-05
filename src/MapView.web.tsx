import React from 'react';
import { Animated, StyleSheet, Text, View } from 'react-native';
import type { MapViewHandle, MapViewProps } from './types';

// M7: react-native-web platform stub. Native maps cannot render on web yet, so
// we show a placeholder and warn once. A real web map (AMap JS API) can replace
// this body later without changing the public API.
let warnedOnce = false;

export const MapView = React.forwardRef<MapViewHandle, MapViewProps>(
  function MapView({ children, style }, ref) {
    React.useEffect(() => {
      if (!warnedOnce && __DEV__) {
        warnedOnce = true;
        console.warn(
          '[react-native-cn-maps] Web is not implemented yet; rendering a placeholder (M7).'
        );
      }
    }, []);

    // Imperative handle is a no-op on web (commands have no map to drive).
    React.useImperativeHandle(ref, () => ({ animateToRegion() {} }), []);

    return (
      <View style={[styles.placeholder, style]}>
        <Text style={styles.text}>Map is unavailable on web</Text>
        {children}
      </View>
    );
  }
);

const styles = StyleSheet.create({
  placeholder: {
    minHeight: 200,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#e9eef5',
  },
  text: {
    color: '#667085',
    fontSize: 14,
  },
});

export const AnimatedMapView = Animated.createAnimatedComponent(MapView);

(MapView as typeof MapView & { Animated: typeof AnimatedMapView }).Animated =
  AnimatedMapView;

export default MapView;
