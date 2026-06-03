import type { MapProvider, MapType } from './types';

/**
 * Default provider for the current build. Maps directly to AMap until other
 * SDKs land in M8 / M9.
 */
export const PROVIDER_DEFAULT: MapProvider = 'amap';

/**
 * RNM exports `PROVIDER_GOOGLE` for opt-in Google Maps. We have no Google
 * provider, so it best-effort maps to the default. Components that read the
 * provider prop should warn in `__DEV__` if they receive a provider they
 * cannot honor.
 */
export const PROVIDER_GOOGLE: MapProvider = PROVIDER_DEFAULT;

/**
 * RNM constant. Keep values in sync with the `MapType` union in `./types`.
 */
export const MAP_TYPES = {
  STANDARD: 'standard',
  SATELLITE: 'satellite',
  HYBRID: 'hybrid',
  TERRAIN: 'terrain',
  NONE: 'none',
  MUTED_STANDARD: 'mutedStandard',
} as const satisfies Record<string, MapType>;

export type MapTypes = (typeof MAP_TYPES)[keyof typeof MAP_TYPES];
