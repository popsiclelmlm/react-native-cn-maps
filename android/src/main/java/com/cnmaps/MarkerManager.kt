package com.cnmaps

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

  companion object {
    const val REACT_CLASS = "RNMapsMarker"
  }
}
