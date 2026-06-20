package com.cnmaps

import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.widget.FrameLayout
import com.cnmaps.adapter.CnGroundOverlayModel
import com.cnmaps.adapter.CnLatLng
import com.cnmaps.adapter.CnOverlayModel
import com.cnmaps.adapter.OverlayHandle
import com.facebook.react.uimanager.ThemedReactContext

/** Provider-agnostic `<Overlay>` (ground overlay) child host component. */
class OverlayView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext), CnOverlayFeature {
  override var cnChildId: String? = null
  override var cnHandle: OverlayHandle? = null
  override var mapHost: CnMapHost? = null

  private var imageUri: String? = null
  private var bitmap: Bitmap? = null
  private var sw: CnLatLng? = null
  private var ne: CnLatLng? = null
  private var bearing: Float = 0f
  private var opacity: Float = 1f
  private var zIndexValue: Float = 0f

  // This view is intercepted by the map and never attached to a window, so
  // View.post {} would never run — schedule on the main looper directly.
  private val mainHandler = Handler(Looper.getMainLooper())

  override fun overlayModel(): CnOverlayModel = CnGroundOverlayModel(
    southWest = sw,
    northEast = ne,
    bitmap = bitmap,
    bearing = bearing,
    opacity = opacity,
    zIndex = zIndexValue
  )

  private fun notifyHost() = mapHost?.onChildModelChanged(this)

  fun setImage(uri: String?) {
    val normalized = if (uri.isNullOrEmpty()) null else uri
    if (normalized == imageUri) {
      return
    }
    imageUri = normalized
    bitmap = null
    if (normalized == null) {
      notifyHost()
    } else {
      loadImage(normalized)
    }
  }

  fun setBounds(swLat: Double, swLng: Double, neLat: Double, neLng: Double) {
    sw = CnLatLng(swLat, swLng)
    ne = CnLatLng(neLat, neLng)
    notifyHost()
  }

  fun setBearingValue(value: Float) { bearing = value; notifyHost() }
  fun setOpacityValue(value: Float) { opacity = value; notifyHost() }
  fun setZIndexValue(value: Float) { zIndexValue = value; notifyHost() }

  private fun loadImage(uri: String) {
    MapsImageLoader.executor.execute {
      val loaded = MapsImageLoader.decode(uri, resources, context.packageName)
      mainHandler.post {
        // Ignore a stale load if the uri changed again before it resolved.
        if (uri == imageUri) {
          bitmap = loaded
          notifyHost()
        }
      }
    }
  }
}
