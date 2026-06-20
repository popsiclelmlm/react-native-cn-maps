package com.cnmaps

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNMapsOverlayManagerDelegate
import com.facebook.react.viewmanagers.RNMapsOverlayManagerInterface

@ReactModule(name = OverlayManager.REACT_CLASS)
class OverlayManager : SimpleViewManager<OverlayView>(),
  RNMapsOverlayManagerInterface<OverlayView> {
  private val delegate: ViewManagerDelegate<OverlayView> =
    RNMapsOverlayManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<OverlayView> = delegate

  override fun getName(): String = REACT_CLASS

  public override fun createViewInstance(context: ThemedReactContext): OverlayView {
    return OverlayView(context)
  }

  @ReactProp(name = "image")
  override fun setImage(view: OverlayView, value: String?) {
    view.setImage(value)
  }

  @ReactProp(name = "swLatitude", defaultDouble = 0.0)
  override fun setSwLatitude(view: OverlayView, value: Double) {
    pendingBounds(view).swLat = value
    flushBounds(view)
  }

  @ReactProp(name = "swLongitude", defaultDouble = 0.0)
  override fun setSwLongitude(view: OverlayView, value: Double) {
    pendingBounds(view).swLng = value
    flushBounds(view)
  }

  @ReactProp(name = "neLatitude", defaultDouble = 0.0)
  override fun setNeLatitude(view: OverlayView, value: Double) {
    pendingBounds(view).neLat = value
    flushBounds(view)
  }

  @ReactProp(name = "neLongitude", defaultDouble = 0.0)
  override fun setNeLongitude(view: OverlayView, value: Double) {
    pendingBounds(view).neLng = value
    flushBounds(view)
  }

  @ReactProp(name = "bearing", defaultDouble = 0.0)
  override fun setBearing(view: OverlayView, value: Double) {
    view.setBearingValue(value.toFloat())
  }

  @ReactProp(name = "opacity", defaultDouble = 1.0)
  override fun setOpacity(view: OverlayView, value: Double) {
    view.setOpacityValue(value.toFloat())
  }

  @ReactProp(name = "overlayZIndex", defaultDouble = 0.0)
  override fun setOverlayZIndex(view: OverlayView, value: Double) {
    view.setZIndexValue(value.toFloat())
  }

  // The four bounds scalars arrive as separate prop updates; collect them and
  // push to the view once a full SW/NE pair is present.
  private class Bounds {
    var swLat: Double? = null
    var swLng: Double? = null
    var neLat: Double? = null
    var neLng: Double? = null
  }

  private val pending = HashMap<OverlayView, Bounds>()

  private fun pendingBounds(view: OverlayView): Bounds =
    pending.getOrPut(view) { Bounds() }

  private fun flushBounds(view: OverlayView) {
    val b = pending[view] ?: return
    val swLat = b.swLat
    val swLng = b.swLng
    val neLat = b.neLat
    val neLng = b.neLng
    if (swLat != null && swLng != null && neLat != null && neLng != null) {
      view.setBounds(swLat, swLng, neLat, neLng)
    }
  }

  override fun onDropViewInstance(view: OverlayView) {
    pending.remove(view)
    super.onDropViewInstance(view)
  }

  companion object {
    const val REACT_CLASS = "RNMapsOverlay"
  }
}
