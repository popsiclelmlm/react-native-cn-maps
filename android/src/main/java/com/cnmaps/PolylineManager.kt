package com.cnmaps

import android.graphics.Color
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNMapsPolylineManagerDelegate
import com.facebook.react.viewmanagers.RNMapsPolylineManagerInterface

@ReactModule(name = PolylineManager.REACT_CLASS)
class PolylineManager : SimpleViewManager<PolylineView>(),
  RNMapsPolylineManagerInterface<PolylineView> {
  private val delegate: ViewManagerDelegate<PolylineView> =
    RNMapsPolylineManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<PolylineView> = delegate

  override fun getName(): String = REACT_CLASS

  public override fun createViewInstance(context: ThemedReactContext): PolylineView {
    return PolylineView(context)
  }

  @ReactProp(name = "coordinates")
  override fun setCoordinates(view: PolylineView, value: ReadableArray?) {
    view.setCoordinatesFromArray(value)
  }

  @ReactProp(name = "strokeColor", customType = "Color")
  override fun setStrokeColor(view: PolylineView, value: Int?) {
    view.setStrokeColorValue(value ?: Color.BLACK)
  }

  @ReactProp(name = "strokeWidth", defaultDouble = 1.0)
  override fun setStrokeWidth(view: PolylineView, value: Double) {
    view.setStrokeWidthValue(value.toFloat())
  }

  @ReactProp(name = "strokeColors")
  override fun setStrokeColors(view: PolylineView, value: String?) {
    view.setStrokeColorsJson(value)
  }

  @ReactProp(name = "lineDashPattern")
  override fun setLineDashPattern(view: PolylineView, value: String?) {
    view.setLineDashPattern(value)
  }

  @ReactProp(name = "lineCap")
  override fun setLineCap(view: PolylineView, value: String?) {
    view.setLineCapValue(value)
  }

  @ReactProp(name = "lineJoin")
  override fun setLineJoin(view: PolylineView, value: String?) {
    view.setLineJoinValue(value)
  }

  @ReactProp(name = "miterLimit", defaultDouble = 10.0)
  override fun setMiterLimit(view: PolylineView, value: Double) {
    // best-effort: AMap Android polyline has no miter-limit setter.
  }

  @ReactProp(name = "geodesic", defaultBoolean = false)
  override fun setGeodesic(view: PolylineView, value: Boolean) {
    view.setGeodesicValue(value)
  }

  @ReactProp(name = "overlayZIndex", defaultDouble = 0.0)
  override fun setOverlayZIndex(view: PolylineView, value: Double) {
    view.setZIndexValue(value.toFloat())
  }

  @ReactProp(name = "tappable", defaultBoolean = false)
  override fun setTappable(view: PolylineView, value: Boolean) {
    // Map-level OnPolylineClickListener routes taps; this gates whether this
    // polyline emits onPress (see MapView.configureMap / PolylineView).
    view.setTappableValue(value)
  }

  companion object {
    const val REACT_CLASS = "RNMapsPolyline"
  }
}
