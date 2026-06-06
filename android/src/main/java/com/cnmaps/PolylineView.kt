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
import org.json.JSONArray

/** `<Polyline>` child host component; holds the AMap [Polyline]. */
class PolylineView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext) {
  private var coordinates: List<LatLng> = emptyList()
  private var strokeColor: Int = Color.BLACK
  private var strokeColors: List<Int> = emptyList()
  private var strokeWidth: Float = 1f
  private var zIndexValue: Float = 0f
  private var geodesic: Boolean = false
  private var dashed: Boolean = false
  private var lineCap: String? = null
  private var lineJoin: String? = null
  private var tappable: Boolean = false
  private var aMap: AMap? = null
  private var polyline: Polyline? = null

  fun setTappableValue(value: Boolean) {
    tappable = value
  }

  // Map-level polyline click routing: the map's OnPolylineClickListener matches
  // the clicked AMap polyline back to its owning view and (if tappable) emits.
  fun handlePolylineClick(clicked: Polyline): Boolean {
    if (!tappable || polyline == null || polyline != clicked) {
      return false
    }
    emitPress()
    return true
  }

  fun setCoordinatesFromArray(array: ReadableArray?) {
    coordinates = parseLatLngArray(array)
    rebuild()
  }

  fun setStrokeColorValue(color: Int) {
    strokeColor = color
    if (strokeColors.isEmpty()) {
      polyline?.color = color
    }
  }

  fun setStrokeColorsJson(json: String?) {
    strokeColors = parseColors(json)
    rebuild()
  }

  fun setLineCapValue(value: String?) {
    lineCap = value
    rebuild()
  }

  fun setLineJoinValue(value: String?) {
    lineJoin = value
    rebuild()
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

  // AMap geometry is immutable per object, so geometry/geodesic/dash/gradient/
  // cap/join changes recreate the polyline; color/width/zIndex update in place.
  private fun rebuild() {
    val map = aMap ?: return
    polyline?.remove()
    val options = PolylineOptions()
      .addAll(coordinates)
      .width(strokeWidth)
      .zIndex(zIndexValue)
      .geodesic(geodesic)
      .setDottedLine(dashed)

    if (strokeColors.size > 1) {
      options.colorValues(ArrayList(strokeColors)).useGradient(true)
    } else if (strokeColors.size == 1) {
      options.color(strokeColors[0])
    } else {
      options.color(strokeColor)
    }

    lineCapType()?.let { options.lineCapType(it) }
    lineJoinType()?.let { options.lineJoinType(it) }

    polyline = map.addPolyline(options)
  }

  private fun lineCapType(): PolylineOptions.LineCapType? = when (lineCap) {
    "butt" -> PolylineOptions.LineCapType.LineCapButt
    "round" -> PolylineOptions.LineCapType.LineCapRound
    "square" -> PolylineOptions.LineCapType.LineCapSquare
    else -> null
  }

  private fun lineJoinType(): PolylineOptions.LineJoinType? = when (lineJoin) {
    "miter" -> PolylineOptions.LineJoinType.LineJoinMiter
    "round" -> PolylineOptions.LineJoinType.LineJoinRound
    "bevel" -> PolylineOptions.LineJoinType.LineJoinBevel
    else -> null
  }

  private fun parseColors(json: String?): List<Int> {
    if (json.isNullOrEmpty()) {
      return emptyList()
    }
    return runCatching {
      val arr = JSONArray(json)
      (0 until arr.length()).mapNotNull { i ->
        runCatching { Color.parseColor(arr.getString(i)) }.getOrNull()
      }
    }.getOrDefault(emptyList())
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
