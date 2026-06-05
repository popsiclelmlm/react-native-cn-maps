package com.cnmaps

import android.content.res.AssetManager
import android.widget.FrameLayout
import com.amap.api.maps.AMap
import com.amap.api.maps.model.Tile
import com.amap.api.maps.model.TileOverlay
import com.amap.api.maps.model.TileOverlayOptions
import com.amap.api.maps.model.TileProvider
import com.facebook.react.uimanager.ThemedReactContext
import java.io.File

/**
 * `<LocalTile>` child host component (M11); holds an AMap [TileOverlay] backed by
 * local files via a `{x}/{y}/{z}` path template (filesystem or app assets).
 */
class LocalTileView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext) {
  private var pathTemplate: String? = null
  private var tileSize: Int = 256
  private var useAssets: Boolean = false
  private var zIndexValue: Float = 0f
  private var aMap: AMap? = null
  private var tileOverlay: TileOverlay? = null

  fun setPathTemplateValue(value: String?) {
    pathTemplate = value
    rebuild()
  }

  fun setTileSizeValue(value: Int) {
    if (value > 0) tileSize = value
    rebuild()
  }

  fun setUseAssetsValue(value: Boolean) {
    useAssets = value
    rebuild()
  }

  fun setZIndexValue(value: Float) {
    zIndexValue = value
    tileOverlay?.setZIndex(value)
  }

  fun attachTo(map: AMap) {
    aMap = map
    rebuild()
  }

  fun detach() {
    tileOverlay?.remove()
    tileOverlay = null
    aMap = null
  }

  private fun rebuild() {
    val map = aMap ?: return
    val template = pathTemplate ?: return
    tileOverlay?.remove()

    val provider = LocalTileProvider(
      tileSize,
      template,
      useAssets,
      if (useAssets) reactContext.assets else null
    )
    tileOverlay = map.addTileOverlay(
      TileOverlayOptions().tileProvider(provider).zIndex(zIndexValue)
    )
  }

  private class LocalTileProvider(
    private val size: Int,
    private val template: String,
    private val useAssets: Boolean,
    private val assets: AssetManager?
  ) : TileProvider {
    override fun getTile(x: Int, y: Int, zoom: Int): Tile {
      val path = template
        .replace("{x}", x.toString())
        .replace("{y}", y.toString())
        .replace("{z}", zoom.toString())
      return try {
        val bytes = if (useAssets && assets != null) {
          assets.open(path).use { it.readBytes() }
        } else {
          File(path).readBytes()
        }
        Tile(size, size, bytes)
      } catch (e: Exception) {
        TileProvider.NO_TILE
      }
    }

    override fun getTileWidth(): Int = size

    override fun getTileHeight(): Int = size
  }
}
