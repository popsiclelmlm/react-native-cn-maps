package com.cnmaps

import android.graphics.Color
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNMapsCircleManagerDelegate
import com.facebook.react.viewmanagers.RNMapsCircleManagerInterface

@ReactModule(name = CircleManager.REACT_CLASS)
class CircleManager : SimpleViewManager<CircleView>(),
  RNMapsCircleManagerInterface<CircleView> {
  private val delegate: ViewManagerDelegate<CircleView> =
    RNMapsCircleManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<CircleView> = delegate

  override fun getName(): String = REACT_CLASS

  public override fun createViewInstance(context: ThemedReactContext): CircleView {
    return CircleView(context)
  }

  @ReactProp(name = "latitude", defaultDouble = 0.0)
  override fun setLatitude(view: CircleView, value: Double) {
    view.setCenterLatitude(value)
  }

  @ReactProp(name = "longitude", defaultDouble = 0.0)
  override fun setLongitude(view: CircleView, value: Double) {
    view.setCenterLongitude(value)
  }

  @ReactProp(name = "radius", defaultDouble = 0.0)
  override fun setRadius(view: CircleView, value: Double) {
    view.setRadiusMeters(value)
  }

  @ReactProp(name = "strokeColor", customType = "Color")
  override fun setStrokeColor(view: CircleView, value: Int?) {
    view.setStrokeColorValue(value ?: Color.BLACK)
  }

  @ReactProp(name = "strokeWidth", defaultDouble = 1.0)
  override fun setStrokeWidth(view: CircleView, value: Double) {
    view.setStrokeWidthValue(value.toFloat())
  }

  @ReactProp(name = "fillColor", customType = "Color")
  override fun setFillColor(view: CircleView, value: Int?) {
    view.setFillColorValue(value ?: Color.argb(64, 0, 0, 0))
  }

  @ReactProp(name = "lineDashPattern")
  override fun setLineDashPattern(view: CircleView, value: String?) {
    // AMap Android circles have no dash style; best-effort ignore.
  }

  @ReactProp(name = "zIndex", defaultDouble = 0.0)
  override fun setZIndex(view: CircleView, value: Double) {
    view.setZIndexValue(value.toFloat())
  }

  @ReactProp(name = "tappable", defaultBoolean = false)
  override fun setTappable(view: CircleView, value: Boolean) {
    // AMap Android exposes no circle click callback; best-effort ignore.
  }

  companion object {
    const val REACT_CLASS = "RNMapsCircle"
  }
}
