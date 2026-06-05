package com.cnmaps

import android.graphics.Color
import android.widget.FrameLayout
import com.amap.api.maps.AMap
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.Polyline
import com.amap.api.maps.model.PolylineOptions
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event

/** `<Polyline>` child host component; holds the AMap [Polyline]. */
class PolylineView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext) {
  private var coordinates: List<LatLng> = emptyList()
  private var strokeColor: Int = Color.BLACK
  private var strokeWidth: Float = 1f
  private var zIndexValue: Float = 0f
  private var geodesic: Boolean = false
  private var dashed: Boolean = false
  private var aMap: AMap? = null
  private var polyline: Polyline? = null

  fun setCoordinatesFromArray(array: ReadableArray?) {
    coordinates = parseLatLngArray(array)
    rebuild()
  }

  fun setStrokeColorValue(color: Int) {
    strokeColor = color
    polyline?.color = color
  }

  fun setStrokeWidthValue(width: Float) {
    strokeWidth = width
    polyline?.width = width
  }

  fun setZIndexValue(value: Float) {
    zIndexValue = value
    polyline?.zIndex = value
  }

  fun setGeodesicValue(value: Boolean) {
    geodesic = value
    rebuild()
  }

  fun setLineDashPattern(json: String?) {
    dashed = !json.isNullOrEmpty() && json != "[]"
    rebuild()
  }

  // Parent-driven attach/detach (MapView feature list).
  fun attachTo(map: AMap) {
    aMap = map
    rebuild()
  }

  fun detach() {
    polyline?.remove()
    polyline = null
    aMap = null
  }

  fun emitPress() {
    if (id == NO_ID) {
      return
    }
    UIManagerHelper.getEventDispatcher(reactContext)?.dispatchEvent(
      OverlayPressEvent(UIManagerHelper.getSurfaceId(this), id)
    )
  }

  // AMap geometry is immutable per object, so geometry/geodesic/dash changes
  // recreate the polyline; color/width/zIndex update in place above.
  private fun rebuild() {
    val map = aMap ?: return
    polyline?.remove()
    polyline = map.addPolyline(
      PolylineOptions()
        .addAll(coordinates)
        .color(strokeColor)
        .width(strokeWidth)
        .zIndex(zIndexValue)
        .geodesic(geodesic)
        .setDottedLine(dashed)
    )
  }

  private fun parseLatLngArray(array: ReadableArray?): List<LatLng> {
    val list = ArrayList<LatLng>()
    if (array == null) {
      return list
    }
    for (i in 0 until array.size()) {
      val m = array.getMap(i) ?: continue
      list.add(LatLng(m.getDouble("latitude"), m.getDouble("longitude")))
    }
    return list
  }

  private class OverlayPressEvent(surfaceId: Int, viewId: Int) :
    Event<OverlayPressEvent>(surfaceId, viewId) {
    override fun getEventName(): String = "topPress"

    override fun canCoalesce(): Boolean = false

    override fun getEventData(): WritableMap = Arguments.createMap()
  }
}
