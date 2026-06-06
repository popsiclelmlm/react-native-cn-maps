import React from 'react';
import NativeUrlTile from './UrlTileNativeComponent';
import type { UrlTileProps } from './types';

/**
 * `<UrlTile>` child host component of `<MapView>`. Renders a raster tile
 * layer from a `{x}/{y}/{z}` URL template. `shouldReplaceMapContent` is accepted
 * for RNM parity but not honored (the base map stays beneath the layer).
 */
function UrlTileComponent(props: UrlTileProps) {
  const {
    urlTemplate,
    minimumZ,
    maximumZ,
    maximumNativeZ,
    tileSize,
    doubleTileSize,
    flipY,
    opacity,
    zIndex,
    offlineMode,
    tileCachePath,
    tileCacheMaxAge,
  } = props;

  return (
    <NativeUrlTile
      urlTemplate={urlTemplate}
      minimumZ={minimumZ}
      maximumZ={maximumZ}
      maximumNativeZ={maximumNativeZ}
      tileSize={tileSize}
      doubleTileSize={doubleTileSize}
      flipY={flipY}
      opacity={opacity}
      overlayZIndex={zIndex}
      offlineMode={offlineMode}
      tileCachePath={tileCachePath}
      tileCacheMaxAge={tileCacheMaxAge}
    />
  );
}

export type UrlTileComponentType = ((
  props: UrlTileProps
) => React.ReactElement) & {
  __MAP_URL_TILE: true;
};

export const UrlTile = UrlTileComponent as unknown as UrlTileComponentType;

UrlTile.__MAP_URL_TILE = true;

export default UrlTile;
export type { UrlTileProps as MapUrlTileProps };
