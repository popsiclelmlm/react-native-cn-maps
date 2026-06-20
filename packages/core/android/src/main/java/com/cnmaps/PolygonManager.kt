package com.cnmaps

import android.graphics.Color
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNMapsPolygonManagerDelegate
import com.facebook.react.viewmanagers.RNMapsPolygonManagerInterface

@ReactModule(name = PolygonManager.REACT_CLASS)
class PolygonManager : SimpleViewManager<PolygonView>(),
  RNMapsPolygonManagerInterface<PolygonView> {
  private val delegate: ViewManagerDelegate<PolygonView> =
    RNMapsPolygonManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<PolygonView> = delegate

  override fun getName(): String = REACT_CLASS

  public override fun createViewInstance(context: ThemedReactContext): PolygonView {
    return PolygonView(context)
  }

  @ReactProp(name = "coordinates")
  override fun setCoordinates(view: PolygonView, value: ReadableArray?) {
    view.setCoordinatesFromArray(value)
  }

  @ReactProp(name = "holes")
  override fun setHoles(view: PolygonView, value: String?) {
    view.setHolesJson(value)
  }

  @ReactProp(name = "strokeColor", customType = "Color")
  override fun setStrokeColor(view: PolygonView, value: Int?) {
    view.setStrokeColorValue(value ?: Color.BLACK)
  }

  @ReactProp(name = "strokeWidth", defaultDouble = 1.0)
  override fun setStrokeWidth(view: PolygonView, value: Double) {
    view.setStrokeWidthValue(value.toFloat())
  }

  @ReactProp(name = "fillColor", customType = "Color")
  override fun setFillColor(view: PolygonView, value: Int?) {
    view.setFillColorValue(value ?: Color.argb(64, 0, 0, 0))
  }

  @ReactProp(name = "lineDashPattern")
  override fun setLineDashPattern(view: PolygonView, value: String?) {
    // AMap Android polygons have no dash style; best-effort ignore.
  }

  @ReactProp(name = "overlayZIndex", defaultDouble = 0.0)
  override fun setOverlayZIndex(view: PolygonView, value: Double) {
    view.setZIndexValue(value.toFloat())
  }

  @ReactProp(name = "tappable", defaultBoolean = false)
  override fun setTappable(view: PolygonView, value: Boolean) {
    // AMap Android exposes no polygon click callback; best-effort ignore.
  }

  companion object {
    const val REACT_CLASS = "RNMapsPolygon"
  }
}
