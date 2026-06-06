package com.cnmaps

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.FrameLayout
import com.amap.api.maps.AMap
import com.amap.api.maps.model.BitmapDescriptorFactory
import com.amap.api.maps.model.GroundOverlay
import com.amap.api.maps.model.GroundOverlayOptions
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.LatLngBounds
import com.facebook.react.uimanager.ThemedReactContext
import java.net.URL

/**
 * `<Overlay>` child host component (M12); holds an AMap [GroundOverlay] that
 * places an image over a geographic bounding box. The image loads asynchronously
 * (a GroundOverlay must be created with its bitmap), so the overlay is only built
 * once the bitmap is ready; any prop change re-builds it.
 */
class OverlayView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext) {
  private var imageUri: String? = null
  private var bitmap: Bitmap? = null
  private var sw: LatLng? = null
  private var ne: LatLng? = null
  private var bearing: Float = 0f
  private var opacity: Float = 1f
  private var zIndexValue: Float = 0f
  private var aMap: AMap? = null
  private var groundOverlay: GroundOverlay? = null

  fun setImage(uri: String?) {
    val normalized = if (uri.isNullOrEmpty()) null else uri
    if (normalized == imageUri) {
      return
    }
    imageUri = normalized
    bitmap = null
    if (normalized == null) {
      rebuild()
    } else {
      loadImage(normalized)
    }
  }

  fun setBounds(swLat: Double, swLng: Double, neLat: Double, neLng: Double) {
    sw = LatLng(swLat, swLng)
    ne = LatLng(neLat, neLng)
    rebuild()
  }

  fun setBearingValue(value: Float) {
    bearing = value
    rebuild()
  }

  fun setOpacityValue(value: Float) {
    opacity = value
    rebuild()
  }

  fun setZIndexValue(value: Float) {
    zIndexValue = value
    rebuild()
  }

  // Parent-driven attach/detach (MapView feature list).
  fun attachTo(map: AMap) {
    aMap = map
    rebuild()
  }

  fun detach() {
    groundOverlay?.remove()
    groundOverlay = null
    aMap = null
  }

  private fun rebuild() {
    val map = aMap ?: return
    val s = sw ?: return
    val n = ne ?: return
    val bmp = bitmap ?: return
    groundOverlay?.remove()
    groundOverlay = map.addGroundOverlay(
      GroundOverlayOptions()
        .positionFromBounds(LatLngBounds(s, n))
        .image(BitmapDescriptorFactory.fromBitmap(bmp))
        .bearing(bearing)
        .transparency((1f - opacity).coerceIn(0f, 1f))
        .zIndex(zIndexValue)
    )
  }

  private fun loadImage(uri: String) {
    Thread {
      val loaded = runCatching {
        when {
          uri.startsWith("http://") || uri.startsWith("https://") ->
            URL(uri).openStream().use { BitmapFactory.decodeStream(it) }
          uri.startsWith("file://") ->
            BitmapFactory.decodeFile(Uri.parse(uri).path)
          else -> {
            val resId =
              resources.getIdentifier(uri, "drawable", context.packageName)
            if (resId != 0) BitmapFactory.decodeResource(resources, resId) else null
          }
        }
      }.getOrNull()

      post {
        // Ignore a stale load if the uri changed again before it resolved.
        if (uri == imageUri) {
          bitmap = loaded
          rebuild()
        }
      }
    }.start()
  }
}
