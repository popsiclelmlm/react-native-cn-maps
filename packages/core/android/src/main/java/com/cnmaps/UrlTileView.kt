package com.cnmaps

import android.widget.FrameLayout
import com.cnmaps.adapter.CnOverlayModel
import com.cnmaps.adapter.CnUrlTileModel
import com.cnmaps.adapter.OverlayHandle
import com.facebook.react.uimanager.ThemedReactContext

/** Provider-agnostic `<UrlTile>` child host component; produces a [CnUrlTileModel]. */
class UrlTileView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext), CnOverlayFeature {
  override var cnChildId: String? = null
  override var cnHandle: OverlayHandle? = null
  override var mapHost: CnMapHost? = null

  private var urlTemplate: String? = null
  private var minimumZ: Int = 0
  private var maximumZ: Int = 25
  private var tileSize: Int = 256
  private var flipY: Boolean = false
  private var wms: Boolean = false
  private var zIndexValue: Float = 0f
  private var diskCacheDir: String? = null

  override fun overlayModel(): CnOverlayModel = CnUrlTileModel(
    urlTemplate = urlTemplate,
    minimumZ = minimumZ,
    maximumZ = maximumZ,
    tileSize = tileSize,
    flipY = flipY,
    wms = wms,
    zIndex = zIndexValue,
    diskCacheDir = diskCacheDir
  )

  private fun notifyHost() = mapHost?.onChildModelChanged(this)

  fun setWmsValue(value: Boolean) { wms = value; notifyHost() }
  fun setUrlTemplateValue(value: String?) { urlTemplate = value; notifyHost() }
  fun setMinimumZValue(value: Int) { minimumZ = value; notifyHost() }
  fun setMaximumZValue(value: Int) { maximumZ = value; notifyHost() }
  fun setTileSizeValue(value: Int) { if (value > 0) tileSize = value; notifyHost() }
  fun setFlipYValue(value: Boolean) { flipY = value; notifyHost() }
  fun setZIndexValue(value: Float) { zIndexValue = value; notifyHost() }
  fun setDiskCacheDir(value: String?) { diskCacheDir = value; notifyHost() }
}
