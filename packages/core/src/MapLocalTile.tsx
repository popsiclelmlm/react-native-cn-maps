import React from 'react';
import NativeLocalTile from './LocalTileNativeComponent';
import type { LocalTileProps } from './types';

/**
 * `<LocalTile>` child host component of `<MapView>`. Renders a raster tile
 * layer read from local files via a `{x}/{y}/{z}` path template.
 */
function LocalTileComponent(props: LocalTileProps) {
  const { pathTemplate, tileSize, useAssets, zIndex } = props;

  return (
    <NativeLocalTile
      pathTemplate={pathTemplate}
      tileSize={tileSize}
      useAssets={useAssets}
      overlayZIndex={zIndex}
    />
  );
}

export type LocalTileComponentType = ((
  props: LocalTileProps
) => React.ReactElement) & {
  __MAP_LOCAL_TILE: true;
};

export const LocalTile =
  LocalTileComponent as unknown as LocalTileComponentType;

LocalTile.__MAP_LOCAL_TILE = true;

export default LocalTile;
export type { LocalTileProps as MapLocalTileProps };
