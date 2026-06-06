package com.cnmaps

import android.graphics.Color
import android.widget.FrameLayout
import com.amap.api.maps.AMap
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.Polygon
import com.amap.api.maps.model.PolygonHoleOptions
import com.amap.api.maps.model.PolygonOptions
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import org.json.JSONArray

/** `<Polygon>` child host component; holds the AMap [Polygon] (with interior holes). */
class PolygonView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext) {
  private var coordinates: List<LatLng> = emptyList()
  private var holes: List<List<LatLng>> = emptyList()
  private var strokeColor: Int = Color.BLACK
  private var fillColor: Int = Color.argb(64, 0, 0, 0)
  private var strokeWidth: Float = 1f
  private var zIndexValue: Float = 0f
  private var aMap: AMap? = null
  private var polygon: Polygon? = null

  fun setCoordinatesFromArray(array: ReadableArray?) {
    coordinates = parseLatLngArray(array)
    rebuild()
  }

  fun setHolesJson(json: String?) {
    holes = parseHoles(json)
    rebuild()
  }

  fun setStrokeColorValue(color: Int) {
    strokeColor = color
    polygon?.strokeColor = color
  }

  fun setFillColorValue(color: Int) {
    fillColor = color
    polygon?.fillColor = color
  }

  fun setStrokeWidthValue(width: Float) {
    strokeWidth = width
    polygon?.strokeWidth = width
  }

  fun setZIndexValue(value: Float) {
    zIndexValue = value
    polygon?.zIndex = value
  }

  fun attachTo(map: AMap) {
    aMap = map
    rebuild()
  }

  fun detach() {
    polygon?.remove()
    polygon = null
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

  private fun rebuild() {
    val map = aMap ?: return
    polygon?.remove()
    val options = PolygonOptions()
      .addAll(coordinates)
      .strokeColor(strokeColor)
      .fillColor(fillColor)
      .strokeWidth(strokeWidth)
      .zIndex(zIndexValue)
    holes.forEach { ring ->
      options.addHoles(PolygonHoleOptions().addAll(ring))
    }
    polygon = map.addPolygon(options)
  }

  private fun parseHoles(json: String?): List<List<LatLng>> {
    if (json.isNullOrEmpty()) {
      return emptyList()
    }
    return runCatching {
      val rings = JSONArray(json)
      (0 until rings.length()).mapNotNull { i ->
        val ring = rings.optJSONArray(i) ?: return@mapNotNull null
        (0 until ring.length()).mapNotNull { j ->
          val p = ring.optJSONObject(j) ?: return@mapNotNull null
          LatLng(p.getDouble("latitude"), p.getDouble("longitude"))
        }.takeIf { it.isNotEmpty() }
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
