package com.cnmaps

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.widget.FrameLayout
import com.amap.api.maps.AMap
import com.amap.api.maps.model.BitmapDescriptor
import com.amap.api.maps.model.BitmapDescriptorFactory
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.Marker
import com.amap.api.maps.model.MarkerOptions
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import java.net.URL

/**
 * Fabric child host component (`RNMapsMarker`) mounted under `MapView`. The view
 * never participates in the FrameLayout's normal layout — the parent `MapView`
 * intercepts its add/remove (via the manager's ViewGroup overrides) and turns it
 * into an AMap `Marker`. The created marker stores this view in `marker.object`
 * so the map's click listener can route callbacks back here.
 */
class MarkerView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext) {
  var identifier: String? = null

  // latitude/longitude arrive as two independent flattened props; each setter
  // pushes the combined position to the live marker once it exists.
  var markerLatitude: Double = 0.0
    set(value) {
      field = value
      marker?.position = LatLng(value, markerLongitude)
    }
  var markerLongitude: Double = 0.0
    set(value) {
      field = value
      marker?.position = LatLng(markerLatitude, value)
    }

  private var title: String? = null
  private var snippet: String? = null
  private var pinColor: String? = null
  private var draggable: Boolean = false

  // Appearance (PR-2). centerOffset/calloutAnchor are iOS positioning hooks with
  // no AMap-Android equivalent, so they are accepted (in the manager) but ignored
  // here; `anchor` is the Android positioning hook.
  private var anchorU: Float = 0.5f
  private var anchorV: Float = 1.0f
  private var opacity: Float = 1.0f
  private var rotation: Float = 0.0f
  private var flat: Boolean = false
  private var zIndexValue: Float = 0.0f
  private var imageUri: String? = null
  private var iconBitmap: Bitmap? = null

  private var marker: Marker? = null

  fun setMarkerTitle(value: String?) {
    title = value
    marker?.title = value ?: ""
  }

  fun setMarkerSnippet(value: String?) {
    snippet = value
    marker?.snippet = value ?: ""
  }

  fun setPinColor(value: String?) {
    pinColor = value
    marker?.let { applyIcon(it) }
  }

  fun setMarkerDraggable(value: Boolean) {
    draggable = value
    marker?.isDraggable = value
  }

  fun setAnchorPoint(u: Float, v: Float) {
    anchorU = u
    anchorV = v
    marker?.setAnchor(u, v)
  }

  fun setOpacity(value: Float) {
    opacity = value
    marker?.alpha = value
  }

  fun setRotationDegrees(value: Float) {
    rotation = value
    marker?.rotateAngle = rnRotationToAMap(value)
  }

  fun setFlatMarker(value: Boolean) {
    flat = value
    marker?.isFlat = value
  }

  fun setZIndexValue(value: Float) {
    zIndexValue = value
    marker?.zIndex = value
  }

  fun setImage(uri: String?) {
    val normalized = if (uri.isNullOrEmpty()) null else uri
    if (normalized == imageUri) {
      return
    }

    imageUri = normalized
    if (normalized == null) {
      iconBitmap = null
      marker?.let { applyIcon(it) }
      return
    }

    loadImage(normalized)
  }

  // Parent-driven attachment ---------------------------------------------------

  fun attachTo(aMap: AMap) {
    if (marker != null) {
      return
    }

    val options = MarkerOptions()
      .position(LatLng(markerLatitude, markerLongitude))
      .draggable(draggable)
      .anchor(anchorU, anchorV)
      .alpha(opacity)
      .setFlat(flat)
      .rotateAngle(rnRotationToAMap(rotation))
      .zIndex(zIndexValue)
      .icon(currentDescriptor())
    title?.let { options.title(it) }
    snippet?.let { options.snippet(it) }

    val created = aMap.addMarker(options)
    created.`object` = this
    marker = created
  }

  fun detach() {
    marker?.remove()
    marker = null
  }

  // Events ---------------------------------------------------------------------

  fun emitPress() {
    if (id == NO_ID) {
      return
    }

    val position = marker?.position ?: LatLng(markerLatitude, markerLongitude)
    UIManagerHelper.getEventDispatcher(reactContext)?.dispatchEvent(
      MarkerPressEvent(
        UIManagerHelper.getSurfaceId(this),
        id,
        position.latitude,
        position.longitude
      )
    )
  }

  private fun applyIcon(target: Marker) {
    target.setIcon(currentDescriptor())
  }

  // A loaded custom bitmap wins; otherwise a hue-tinted default pin; otherwise the
  // plain default marker.
  private fun currentDescriptor(): BitmapDescriptor {
    val bitmap = iconBitmap
    if (bitmap != null) {
      return BitmapDescriptorFactory.fromBitmap(bitmap)
    }

    val hue = markerHue(pinColor)
    return if (hue != null) {
      BitmapDescriptorFactory.defaultMarker(hue)
    } else {
      BitmapDescriptorFactory.defaultMarker()
    }
  }

  // Best-effort, dependency-free decode: http(s) over the network (covers the
  // Metro-served dev asset uri), file:// from disk, otherwise a drawable resource
  // name. Decoding runs off the UI thread; the result is applied back on it.
  private fun loadImage(uri: String) {
    Thread {
      val bitmap = runCatching {
        when {
          uri.startsWith("http://") || uri.startsWith("https://") ->
            URL(uri).openStream().use { BitmapFactory.decodeStream(it) }
          uri.startsWith("file://") ->
            BitmapFactory.decodeFile(Uri.parse(uri).path)
          else -> {
            val resId = resources.getIdentifier(uri, "drawable", context.packageName)
            if (resId != 0) BitmapFactory.decodeResource(resources, resId) else null
          }
        }
      }.getOrNull()

      post {
        // Ignore a stale load if the uri changed again before it resolved.
        if (uri == imageUri) {
          iconBitmap = bitmap
          marker?.let { applyIcon(it) }
        }
      }
    }.start()
  }

  private fun markerHue(color: String?): Float? {
    if (color == null) {
      return null
    }

    return runCatching {
      val hsv = FloatArray(3)
      Color.colorToHSV(Color.parseColor(color), hsv)
      hsv[0]
    }.getOrNull()
  }

  // RNM rotation is clockwise degrees; AMap's rotateAngle is counterclockwise, so
  // invert and normalize into [0, 360).
  private fun rnRotationToAMap(degrees: Float): Float {
    val normalized = (360f - (degrees % 360f)) % 360f
    return if (normalized < 0f) normalized + 360f else normalized
  }

  private class MarkerPressEvent(
    surfaceId: Int,
    viewId: Int,
    private val latitude: Double,
    private val longitude: Double
  ) : Event<MarkerPressEvent>(surfaceId, viewId) {
    override fun getEventName(): String = "topPress"

    override fun canCoalesce(): Boolean = false

    override fun getEventData(): WritableMap =
      Arguments.createMap().apply {
        putMap(
          "coordinate",
          Arguments.createMap().apply {
            putDouble("latitude", latitude)
            putDouble("longitude", longitude)
          }
        )
      }
  }
}
