import type { MapProvider, MapType } from './types';

/**
 * Default provider for the current build. Maps to AMap; Baidu / Tencent
 * providers are planned.
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
  // RNM spells this key without an underscore; expose both for parity.
  MUTEDSTANDARD: 'mutedStandard',
  MUTED_STANDARD: 'mutedStandard',
  SATELLITE_FLYOVER: 'satelliteFlyover',
  HYBRID_FLYOVER: 'hybridFlyover',
} as const satisfies Record<string, MapType>;

export type MapTypes = (typeof MAP_TYPES)[keyof typeof MAP_TYPES];
