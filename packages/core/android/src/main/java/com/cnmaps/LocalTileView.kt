package com.cnmaps

import android.widget.FrameLayout
import com.cnmaps.adapter.CnLocalTileModel
import com.cnmaps.adapter.CnOverlayModel
import com.cnmaps.adapter.OverlayHandle
import com.facebook.react.uimanager.ThemedReactContext

/** Provider-agnostic `<LocalTile>` child host component; produces a [CnLocalTileModel]. */
class LocalTileView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext), CnOverlayFeature {
  override var cnChildId: String? = null
  override var cnHandle: OverlayHandle? = null
  override var mapHost: CnMapHost? = null

  private var pathTemplate: String? = null
  private var tileSize: Int = 256
  private var useAssets: Boolean = false
  private var zIndexValue: Float = 0f

  override fun overlayModel(): CnOverlayModel = CnLocalTileModel(
    pathTemplate = pathTemplate,
    tileSize = tileSize,
    useAssets = useAssets,
    zIndex = zIndexValue
  )

  private fun notifyHost() = mapHost?.onChildModelChanged(this)

  fun setPathTemplateValue(value: String?) { pathTemplate = value; notifyHost() }
  fun setTileSizeValue(value: Int) { if (value > 0) tileSize = value; notifyHost() }
  fun setUseAssetsValue(value: Boolean) { useAssets = value; notifyHost() }
  fun setZIndexValue(value: Float) { zIndexValue = value; notifyHost() }
}
