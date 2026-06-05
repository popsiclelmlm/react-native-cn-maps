package com.cnmaps

import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNMapsMarkerManagerDelegate
import com.facebook.react.viewmanagers.RNMapsMarkerManagerInterface

@ReactModule(name = MarkerManager.REACT_CLASS)
class MarkerManager : ViewGroupManager<MarkerView>(),
  RNMapsMarkerManagerInterface<MarkerView> {
  private val delegate: ViewManagerDelegate<MarkerView> =
    RNMapsMarkerManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<MarkerView> = delegate

  override fun getName(): String = REACT_CLASS

  public override fun createViewInstance(context: ThemedReactContext): MarkerView {
    return MarkerView(context)
  }

  @ReactProp(name = "identifier")
  override fun setIdentifier(view: MarkerView, value: String?) {
    view.identifier = value
  }

  @ReactProp(name = "latitude", defaultDouble = 0.0)
  override fun setLatitude(view: MarkerView, value: Double) {
    view.markerLatitude = value
  }

  @ReactProp(name = "longitude", defaultDouble = 0.0)
  override fun setLongitude(view: MarkerView, value: Double) {
    view.markerLongitude = value
  }

  @ReactProp(name = "title")
  override fun setTitle(view: MarkerView, value: String?) {
    view.setMarkerTitle(value)
  }

  @ReactProp(name = "description")
  override fun setDescription(view: MarkerView, value: String?) {
    view.setMarkerSnippet(value)
  }

  @ReactProp(name = "pinColor")
  override fun setPinColor(view: MarkerView, value: String?) {
    view.setPinColor(value)
  }

  @ReactProp(name = "draggable", defaultBoolean = false)
  override fun setDraggable(view: MarkerView, value: Boolean) {
    view.setMarkerDraggable(value)
  }

  // Appearance (PR-2) ----------------------------------------------------------

  @ReactProp(name = "image")
  override fun setImage(view: MarkerView, value: String?) {
    view.setImage(value)
  }

  @ReactProp(name = "anchor")
  override fun setAnchor(view: MarkerView, value: ReadableMap?) {
    if (value != null) {
      view.setAnchorPoint(
        value.pointComponent("x"),
        value.pointComponent("y")
      )
    }
  }

  @ReactProp(name = "centerOffset")
  override fun setCenterOffset(view: MarkerView, value: ReadableMap?) {
    // iOS annotation-view offset; no AMap-Android equivalent (anchor positions
    // the marker). Best-effort ignore.
  }

  @ReactProp(name = "calloutAnchor")
  override fun setCalloutAnchor(view: MarkerView, value: ReadableMap?) {
    // iOS callout offset; AMap Android's info window offset is not settable.
    // Best-effort ignore.
  }

  @ReactProp(name = "opacity", defaultDouble = 1.0)
  override fun setOpacity(view: MarkerView, value: Double) {
    view.setOpacity(value.toFloat())
  }

  @ReactProp(name = "rotation", defaultDouble = 0.0)
  override fun setRotation(view: MarkerView, value: Double) {
    view.setRotationDegrees(value.toFloat())
  }

  @ReactProp(name = "flat", defaultBoolean = false)
  override fun setFlat(view: MarkerView, value: Boolean) {
    view.setFlatMarker(value)
  }

  @ReactProp(name = "zIndex", defaultDouble = 0.0)
  override fun setZIndex(view: MarkerView, value: Double) {
    view.setZIndexValue(value.toFloat())
  }

  // Custom React content (PR-3) -----------------------------------------------

  @ReactProp(name = "tracksViewChanges", defaultBoolean = true)
  override fun setTracksViewChanges(view: MarkerView, value: Boolean) {
    view.setTracksViewChanges(value)
  }

  @ReactProp(name = "tracksInfoWindowChanges", defaultBoolean = false)
  override fun setTracksInfoWindowChanges(view: MarkerView, value: Boolean) {
    view.setTracksInfoWindowChanges(value)
  }

  // Commands (PR-4) ------------------------------------------------------------

  override fun showCallout(view: MarkerView) {
    view.showCallout()
  }

  override fun hideCallout(view: MarkerView) {
    view.hideCallout()
  }

  override fun redrawCallout(view: MarkerView) {
    view.redrawCallout()
  }

  override fun redraw(view: MarkerView) {
    view.redraw()
  }

  override fun animateMarkerToCoordinate(
    view: MarkerView,
    latitude: Double,
    longitude: Double,
    duration: Int
  ) {
    view.animateToCoordinate(latitude, longitude, duration)
  }

  private fun ReadableMap.pointComponent(key: String): Float {
    return if (hasKey(key) && !isNull(key)) getDouble(key).toFloat() else 0f
  }

  companion object {
    const val REACT_CLASS = "RNMapsMarker"
  }
}
