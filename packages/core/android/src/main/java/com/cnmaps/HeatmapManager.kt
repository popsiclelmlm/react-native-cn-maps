package com.cnmaps

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNMapsHeatmapManagerDelegate
import com.facebook.react.viewmanagers.RNMapsHeatmapManagerInterface

@ReactModule(name = HeatmapManager.REACT_CLASS)
class HeatmapManager : SimpleViewManager<HeatmapView>(),
  RNMapsHeatmapManagerInterface<HeatmapView> {
  private val delegate: ViewManagerDelegate<HeatmapView> =
    RNMapsHeatmapManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<HeatmapView> = delegate

  override fun getName(): String = REACT_CLASS

  public override fun createViewInstance(context: ThemedReactContext): HeatmapView {
    return HeatmapView(context)
  }

  @ReactProp(name = "points")
  override fun setPoints(view: HeatmapView, value: String?) {
    view.setPointsJson(value)
  }

  @ReactProp(name = "radius", defaultInt = 20)
  override fun setRadius(view: HeatmapView, value: Int) {
    view.setRadiusValue(value)
  }

  @ReactProp(name = "opacity", defaultDouble = 0.6)
  override fun setOpacity(view: HeatmapView, value: Double) {
    // best-effort: AMap Android heatmap exposes no overlay-level opacity API.
  }

  @ReactProp(name = "gradient")
  override fun setGradient(view: HeatmapView, value: String?) {
    view.setGradientJson(value)
  }

  companion object {
    const val REACT_CLASS = "RNMapsHeatmap"
  }
}
