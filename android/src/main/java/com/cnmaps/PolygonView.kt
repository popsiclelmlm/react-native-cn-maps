package com.cnmaps

import android.graphics.Color
import android.widget.FrameLayout
import com.cnmaps.adapter.CnLatLng
import com.cnmaps.adapter.CnOverlayModel
import com.cnmaps.adapter.CnPolygonModel
import com.cnmaps.adapter.OverlayHandle
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.uimanager.ThemedReactContext
import org.json.JSONArray

/** Provider-agnostic `<Polygon>` child host component; produces a [CnPolygonModel]. */
class PolygonView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext), CnOverlayFeature {
  override var cnChildId: String? = null
  override var cnHandle: OverlayHandle? = null
  override var mapHost: CnMapHost? = null

  private var coordinates: List<CnLatLng> = emptyList()
  private var holes: List<List<CnLatLng>> = emptyList()
  private var strokeColor: Int = Color.BLACK
  private var fillColor: Int = Color.argb(64, 0, 0, 0)
  private var strokeWidth: Float = 1f
  private var zIndexValue: Float = 0f

  override fun overlayModel(): CnOverlayModel = CnPolygonModel(
    coordinates = coordinates,
    holes = holes,
    strokeColor = strokeColor,
    fillColor = fillColor,
    strokeWidth = strokeWidth,
    zIndex = zIndexValue
  )

  private fun notifyHost() = mapHost?.onChildModelChanged(this)

  fun setCoordinatesFromArray(array: ReadableArray?) { coordinates = parseLatLngArray(array); notifyHost() }
  fun setHolesJson(json: String?) { holes = parseHoles(json); notifyHost() }
  fun setStrokeColorValue(color: Int) { strokeColor = color; notifyHost() }
  fun setFillColorValue(color: Int) { fillColor = color; notifyHost() }
  fun setStrokeWidthValue(width: Float) { strokeWidth = width; notifyHost() }
  fun setZIndexValue(value: Float) { zIndexValue = value; notifyHost() }

  private fun parseHoles(json: String?): List<List<CnLatLng>> {
    if (json.isNullOrEmpty()) {
      return emptyList()
    }
    return runCatching {
      val rings = JSONArray(json)
      (0 until rings.length()).mapNotNull { i ->
        val ring = rings.optJSONArray(i) ?: return@mapNotNull null
        (0 until ring.length()).mapNotNull { j ->
          val p = ring.optJSONObject(j) ?: return@mapNotNull null
          CnLatLng(p.getDouble("latitude"), p.getDouble("longitude"))
        }.takeIf { it.isNotEmpty() }
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
}
