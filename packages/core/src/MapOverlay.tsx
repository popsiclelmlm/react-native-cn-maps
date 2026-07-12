import React from 'react';
import { Animated, Image } from 'react-native';
import NativeOverlay from './OverlayNativeComponent';
import { MapCoordinateSystemContext, MapProviderContext } from './MapContext';
import { toProviderCoordinate } from './coordinate';
import type { LatLng, LatLngBoundsCorner, OverlayProps } from './types';

/**
 * Coerce a bounds corner into a `LatLng`. Accepts both a `{latitude, longitude}`
 * object and a `[latitude, longitude]` tuple (react-native-maps convention).
 */
function toLatLng(corner: LatLngBoundsCorner): LatLng {
  return Array.isArray(corner)
    ? { latitude: corner[0], longitude: corner[1] }
    : corner;
}

/**
 * Normalize two arbitrary corners into south-west / north-east corners
 * (sw = min lat/lng, ne = max lat/lng), so callers can pass the RNM `bounds`
 * pair in either order. Pure — both corners must already be in the provider
 * coordinate system.
 */
export function normalizeOverlayBounds(a: LatLng, b: LatLng) {
  return {
    sw: {
      latitude: Math.min(a.latitude, b.latitude),
      longitude: Math.min(a.longitude, b.longitude),
    },
    ne: {
      latitude: Math.max(a.latitude, b.latitude),
      longitude: Math.max(a.longitude, b.longitude),
    },
  };
}

function resolveImageUri(source: OverlayProps['image'] | undefined) {
  if (source == null) {
    return undefined;
  }
  // A bare URL string (react-native-maps allows it) isn't handled by
  // resolveAssetSource — pass it straight through.
  if (typeof source === 'string') {
    return source;
  }
  return Image.resolveAssetSource(source)?.uri;
}

/**
 * `<Overlay>` child host component of `<MapView>`. Places an image by a
 * geographic bounding box. `tappable`/`onPress` are accepted for RNM parity but
 * ground overlays have no native tap support.
 */
function OverlayComponent(props: OverlayProps) {
  const { image, bounds, bearing, opacity, zIndex } = props;

  const coordinateSystem = React.useContext(MapCoordinateSystemContext);
  const provider = React.useContext(MapProviderContext);
  const [cornerA, cornerB] = bounds ?? [];
  const normalized =
    cornerA && cornerB
      ? normalizeOverlayBounds(
          toProviderCoordinate(toLatLng(cornerA), coordinateSystem, provider),
          toProviderCoordinate(toLatLng(cornerB), coordinateSystem, provider)
        )
      : undefined;

  return (
    <NativeOverlay
      image={resolveImageUri(image)}
      swLatitude={normalized?.sw.latitude}
      swLongitude={normalized?.sw.longitude}
      neLatitude={normalized?.ne.latitude}
      neLongitude={normalized?.ne.longitude}
      bearing={bearing}
      opacity={opacity}
      overlayZIndex={zIndex}
    />
  );
}

export type OverlayComponentType = ((
  props: OverlayProps
) => React.ReactElement) & {
  __MAP_OVERLAY: true;
  Animated: ReturnType<typeof Animated.createAnimatedComponent>;
};

export const Overlay = OverlayComponent as unknown as OverlayComponentType;

Overlay.__MAP_OVERLAY = true;

// RNM parity: `Overlay.Animated`, also re-exported as `OverlayAnimated`.
Overlay.Animated = Animated.createAnimatedComponent(
  Overlay
) as OverlayComponentType['Animated'];

export default Overlay;
export type { OverlayProps as MapOverlayProps };
