package com.cnmaps

import android.graphics.Color
import android.widget.FrameLayout
import com.cnmaps.adapter.CnCircleModel
import com.cnmaps.adapter.CnLatLng
import com.cnmaps.adapter.CnOverlayModel
import com.cnmaps.adapter.OverlayHandle
import com.facebook.react.uimanager.ThemedReactContext

/** Provider-agnostic `<Circle>` child host component; produces a [CnCircleModel]. */
class CircleView(context: ThemedReactContext) : FrameLayout(context), CnOverlayFeature {
  override var cnChildId: String? = null
  override var cnHandle: OverlayHandle? = null
  override var mapHost: CnMapHost? = null

  private var centerLatitude: Double = 0.0
  private var centerLongitude: Double = 0.0
  private var radiusMeters: Double = 0.0
  private var strokeColor: Int = Color.BLACK
  private var fillColor: Int = Color.argb(64, 0, 0, 0)
  private var strokeWidth: Float = 1f
  private var zIndexValue: Float = 0f

  override fun overlayModel(): CnOverlayModel = CnCircleModel(
    center = CnLatLng(centerLatitude, centerLongitude),
    radius = radiusMeters,
    strokeColor = strokeColor,
    fillColor = fillColor,
    strokeWidth = strokeWidth,
    zIndex = zIndexValue
  )

  private fun notifyHost() = mapHost?.onChildModelChanged(this)

  fun setCenterLatitude(value: Double) { centerLatitude = value; notifyHost() }
  fun setCenterLongitude(value: Double) { centerLongitude = value; notifyHost() }
  fun setRadiusMeters(value: Double) { radiusMeters = value; notifyHost() }
  fun setStrokeColorValue(color: Int) { strokeColor = color; notifyHost() }
  fun setFillColorValue(color: Int) { fillColor = color; notifyHost() }
  fun setStrokeWidthValue(width: Float) { strokeWidth = width; notifyHost() }
  fun setZIndexValue(value: Float) { zIndexValue = value; notifyHost() }
}
