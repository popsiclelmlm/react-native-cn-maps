package com.cnmaps

import android.graphics.Color
import android.widget.FrameLayout
import com.amap.api.maps.AMap
import com.amap.api.maps.model.BitmapDescriptorFactory
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.Marker
import com.amap.api.maps.model.MarkerOptions
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event

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

  // Parent-driven attachment ---------------------------------------------------

  fun attachTo(aMap: AMap) {
    if (marker != null) {
      return
    }

    val options = MarkerOptions()
      .position(LatLng(markerLatitude, markerLongitude))
      .draggable(draggable)
    title?.let { options.title(it) }
    snippet?.let { options.snippet(it) }
    markerHue(pinColor)?.let { options.icon(BitmapDescriptorFactory.defaultMarker(it)) }

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
    val hue = markerHue(pinColor)
    target.setIcon(
      if (hue != null) {
        BitmapDescriptorFactory.defaultMarker(hue)
      } else {
        BitmapDescriptorFactory.defaultMarker()
      }
    )
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
