package com.cnmaps

import android.graphics.Color
import android.widget.FrameLayout
import com.cnmaps.adapter.CnHeatmapModel
import com.cnmaps.adapter.CnHeatmapWeightedPoint
import com.cnmaps.adapter.CnOverlayModel
import com.cnmaps.adapter.OverlayHandle
import com.facebook.react.uimanager.ThemedReactContext
import org.json.JSONArray
import org.json.JSONObject

/** Provider-agnostic `<Heatmap>` child host component; produces a [CnHeatmapModel]. */
class HeatmapView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext), CnOverlayFeature {
  override var cnChildId: String? = null
  override var cnHandle: OverlayHandle? = null
  override var mapHost: CnMapHost? = null

  private var points: List<CnHeatmapWeightedPoint> = emptyList()
  private var radius: Int = 20
  private var gradientColors: IntArray? = null
  private var gradientStartPoints: FloatArray? = null

  override fun overlayModel(): CnOverlayModel = CnHeatmapModel(
    points = points,
    radius = radius,
    gradientColors = gradientColors,
    gradientStartPoints = gradientStartPoints
  )

  private fun notifyHost() = mapHost?.onChildModelChanged(this)

  fun setPointsJson(json: String?) { points = parsePoints(json); notifyHost() }
  fun setRadiusValue(value: Int) { radius = if (value > 0) value else 20; notifyHost() }
  fun setGradientJson(json: String?) { parseGradient(json); notifyHost() }

  private fun parsePoints(json: String?): List<CnHeatmapWeightedPoint> {
    if (json.isNullOrEmpty()) {
      return emptyList()
    }
    return runCatching {
      val arr = JSONArray(json)
      (0 until arr.length()).mapNotNull { i ->
        val o = arr.optJSONObject(i) ?: return@mapNotNull null
        CnHeatmapWeightedPoint(o.getDouble("latitude"), o.getDouble("longitude"), o.optDouble("weight", 1.0))
      }
    }.getOrDefault(emptyList())
  }

  private fun parseGradient(json: String?) {
    if (json.isNullOrEmpty()) {
      gradientColors = null
      gradientStartPoints = null
      return
    }
    runCatching {
      val o = JSONObject(json)
      val colorsArr = o.getJSONArray("colors")
      val startArr = o.getJSONArray("startPoints")
      val colors = IntArray(colorsArr.length()) { Color.parseColor(colorsArr.getString(it)) }
      val starts = FloatArray(startArr.length()) { startArr.getDouble(it).toFloat() }
      if (colors.isEmpty() || colors.size != starts.size) {
        gradientColors = null
        gradientStartPoints = null
      } else {
        gradientColors = colors
        gradientStartPoints = starts
      }
    }.onFailure {
      gradientColors = null
      gradientStartPoints = null
    }
  }
}
