import type { MarkerProps } from './types';

/**
 * RNM's `pinColor` is a `ColorValue`, but the native marker layer only consumes a
 * plain color string. Processed/opaque color values (which arrive as numbers) and
 * `undefined` have no string form, so they fall through to the default pin.
 */
export function markerColorToString(
  color: MarkerProps['pinColor']
): string | undefined {
  return typeof color === 'string' ? color : undefined;
}
