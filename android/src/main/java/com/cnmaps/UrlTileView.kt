package com.cnmaps

import android.widget.FrameLayout
import com.amap.api.maps.AMap
import com.amap.api.maps.model.TileOverlay
import com.amap.api.maps.model.TileOverlayOptions
import com.amap.api.maps.model.UrlTileProvider
import com.facebook.react.uimanager.ThemedReactContext
import java.net.MalformedURLException
import java.net.URL

/**
 * `<UrlTile>` child host component (M11); holds an AMap [TileOverlay] backed by a
 * `{x}/{y}/{z}` URL template. Geometry/zoom/cache changes recreate the overlay;
 * zIndex updates in place.
 */
class UrlTileView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext) {
  private var urlTemplate: String? = null
  private var minimumZ: Int = 0
  private var maximumZ: Int = 25
  private var tileSize: Int = 256
  private var flipY: Boolean = false
  private var zIndexValue: Float = 0f
  private var diskCacheDir: String? = null
  private var aMap: AMap? = null
  private var tileOverlay: TileOverlay? = null

  fun setUrlTemplateValue(value: String?) {
    urlTemplate = value
    rebuild()
  }

  fun setMinimumZValue(value: Int) {
    minimumZ = value
    rebuild()
  }

  fun setMaximumZValue(value: Int) {
    maximumZ = value
    rebuild()
  }

  fun setTileSizeValue(value: Int) {
    if (value > 0) tileSize = value
    rebuild()
  }

  fun setFlipYValue(value: Boolean) {
    flipY = value
    rebuild()
  }

  fun setZIndexValue(value: Float) {
    zIndexValue = value
    tileOverlay?.setZIndex(value)
  }

  fun setDiskCacheDir(value: String?) {
    diskCacheDir = value
    rebuild()
  }

  // Parent-driven attach/detach (MapView feature list).
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
    val template = urlTemplate ?: return
    tileOverlay?.remove()

    val provider = object : UrlTileProvider(tileSize, tileSize) {
      override fun getTileUrl(x: Int, y: Int, zoom: Int): URL? {
        if (zoom < minimumZ || zoom > maximumZ) {
          return null
        }
        val yy = if (flipY) (1 shl zoom) - 1 - y else y
        val url = template
          .replace("{x}", x.toString())
          .replace("{y}", yy.toString())
          .replace("{z}", zoom.toString())
        return try {
          URL(url)
        } catch (e: MalformedURLException) {
          null
        }
      }
    }

    val options = TileOverlayOptions().tileProvider(provider).zIndex(zIndexValue)
    val cacheDir = diskCacheDir
    if (!cacheDir.isNullOrEmpty()) {
      options.diskCacheEnabled(true).diskCacheDir(cacheDir)
    }
    tileOverlay = map.addTileOverlay(options)
  }
}
