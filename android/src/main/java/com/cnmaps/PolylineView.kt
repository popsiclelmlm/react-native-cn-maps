package com.cnmaps

import android.graphics.Color
import android.widget.FrameLayout
import com.cnmaps.adapter.CnLatLng
import com.cnmaps.adapter.CnOverlayModel
import com.cnmaps.adapter.CnPolylineModel
import com.cnmaps.adapter.OverlayHandle
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import org.json.JSONArray

/** Provider-agnostic `<Polyline>` child host component; produces a [CnPolylineModel]. */
class PolylineView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext), CnOverlayFeature {
  override var cnChildId: String? = null
  override var cnHandle: OverlayHandle? = null
  override var mapHost: CnMapHost? = null

  private var coordinates: List<CnLatLng> = emptyList()
  private var strokeColor: Int = Color.BLACK
  private var strokeColors: List<Int> = emptyList()
  private var strokeWidth: Float = 1f
  private var zIndexValue: Float = 0f
  private var geodesic: Boolean = false
  private var dashed: Boolean = false
  private var lineCap: String? = null
  private var lineJoin: String? = null
  private var tappable: Boolean = false

  override fun overlayModel(): CnOverlayModel = CnPolylineModel(
    coordinates = coordinates,
    strokeColor = strokeColor,
    strokeColors = strokeColors,
    strokeWidth = strokeWidth,
    zIndex = zIndexValue,
    geodesic = geodesic,
    dashed = dashed,
    lineCap = lineCap,
    lineJoin = lineJoin,
    tappable = tappable
  )

  private fun notifyHost() = mapHost?.onChildModelChanged(this)

  fun setTappableValue(value: Boolean) { tappable = value; notifyHost() }
  fun setCoordinatesFromArray(array: ReadableArray?) { coordinates = parseLatLngArray(array); notifyHost() }
  fun setStrokeColorValue(color: Int) { strokeColor = color; notifyHost() }
  fun setStrokeColorsJson(json: String?) { strokeColors = parseColors(json); notifyHost() }
  fun setLineCapValue(value: String?) { lineCap = value; notifyHost() }
  fun setLineJoinValue(value: String?) { lineJoin = value; notifyHost() }
  fun setStrokeWidthValue(width: Float) { strokeWidth = width; notifyHost() }
  fun setZIndexValue(value: Float) { zIndexValue = value; notifyHost() }
  fun setGeodesicValue(value: Boolean) { geodesic = value; notifyHost() }
  fun setLineDashPattern(json: String?) { dashed = !json.isNullOrEmpty() && json != "[]"; notifyHost() }

  // Called by the host when the adapter reports a tappable polyline click.
  fun emitPress() {
    if (id == NO_ID) {
      return
    }
    UIManagerHelper.getEventDispatcher(reactContext)?.dispatchEvent(
      OverlayPressEvent(UIManagerHelper.getSurfaceId(this), id)
    )
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

  private fun parseLatLngArray(array: ReadableArray?): List<CnLatLng> {
    val list = ArrayList<CnLatLng>()
    if (array == null) {
      return list
    }
    for (i in 0 until array.size()) {
      val m = array.getMap(i) ?: continue
      list.add(CnLatLng(m.getDouble("latitude"), m.getDouble("longitude")))
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
