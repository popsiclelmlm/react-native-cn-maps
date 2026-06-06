import React from 'react';
import NativeUrlTile from './UrlTileNativeComponent';
import type { WMSTileProps } from './types';

/**
 * `<WMSTile>` child host component of `<MapView>` (M18). A WMS GetMap layer: the
 * `urlTemplate` uses bbox placeholders (`{minX}/{minY}/{maxX}/{maxY}/{width}/
 * {height}`). It reuses the UrlTile native component with `wms` enabled, which
 * substitutes the tile's EPSG:3857 bbox natively. Web Mercator (3857) only.
 */
function WMSTileComponent(props: WMSTileProps) {
  const {
    urlTemplate,
    minimumZ,
    maximumZ,
    maximumNativeZ,
    tileSize,
    opacity,
    zIndex,
    offlineMode,
    tileCachePath,
    tileCacheMaxAge,
  } = props;

  return (
    <NativeUrlTile
      wms
      urlTemplate={urlTemplate}
      minimumZ={minimumZ}
      maximumZ={maximumZ}
      maximumNativeZ={maximumNativeZ}
      tileSize={tileSize}
      opacity={opacity}
      overlayZIndex={zIndex}
      offlineMode={offlineMode}
      tileCachePath={tileCachePath}
      tileCacheMaxAge={tileCacheMaxAge}
    />
  );
}

export type WMSTileComponentType = ((
  props: WMSTileProps
) => React.ReactElement) & {
  __MAP_WMS_TILE: true;
};

export const WMSTile = WMSTileComponent as unknown as WMSTileComponentType;

WMSTile.__MAP_WMS_TILE = true;

export default WMSTile;
export type { WMSTileProps as MapWMSTileProps };
