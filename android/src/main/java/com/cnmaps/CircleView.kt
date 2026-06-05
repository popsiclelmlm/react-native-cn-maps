package com.cnmaps

import android.graphics.Color
import android.widget.FrameLayout
import com.amap.api.maps.AMap
import com.amap.api.maps.model.Circle
import com.amap.api.maps.model.CircleOptions
import com.amap.api.maps.model.LatLng
import com.facebook.react.uimanager.ThemedReactContext

/** `<Circle>` child host component; holds the AMap [Circle]. */
class CircleView(context: ThemedReactContext) : FrameLayout(context) {
  private var centerLatitude: Double = 0.0
  private var centerLongitude: Double = 0.0
  private var radiusMeters: Double = 0.0
  private var strokeColor: Int = Color.BLACK
  private var fillColor: Int = Color.argb(64, 0, 0, 0)
  private var strokeWidth: Float = 1f
  private var zIndexValue: Float = 0f
  private var aMap: AMap? = null
  private var circle: Circle? = null

  fun setCenterLatitude(value: Double) {
    centerLatitude = value
    circle?.center = LatLng(centerLatitude, centerLongitude)
  }

  fun setCenterLongitude(value: Double) {
    centerLongitude = value
    circle?.center = LatLng(centerLatitude, centerLongitude)
  }

  fun setRadiusMeters(value: Double) {
    radiusMeters = value
    circle?.radius = value
  }

  fun setStrokeColorValue(color: Int) {
    strokeColor = color
    circle?.strokeColor = color
  }

  fun setFillColorValue(color: Int) {
    fillColor = color
    circle?.fillColor = color
  }

  fun setStrokeWidthValue(width: Float) {
    strokeWidth = width
    circle?.strokeWidth = width
  }

  fun setZIndexValue(value: Float) {
    zIndexValue = value
    circle?.zIndex = value
  }

  fun attachTo(map: AMap) {
    aMap = map
    rebuild()
  }

  fun detach() {
    circle?.remove()
    circle = null
    aMap = null
  }

  private fun rebuild() {
    val map = aMap ?: return
    circle?.remove()
    circle = map.addCircle(
      CircleOptions()
        .center(LatLng(centerLatitude, centerLongitude))
        .radius(radiusMeters)
        .strokeColor(strokeColor)
        .fillColor(fillColor)
        .strokeWidth(strokeWidth)
        .zIndex(zIndexValue)
    )
  }
}
