package com.cnmaps

import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNMapsMapViewManagerDelegate
import com.facebook.react.viewmanagers.RNMapsMapViewManagerInterface

@ReactModule(name = MapViewManager.REACT_CLASS)
class MapViewManager : SimpleViewManager<MapView>(),
  RNMapsMapViewManagerInterface<MapView> {
  private val delegate: ViewManagerDelegate<MapView> = RNMapsMapViewManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<MapView> = delegate

  override fun getName(): String = REACT_CLASS

  public override fun createViewInstance(context: ThemedReactContext): MapView {
    return MapView(context)
  }

  override fun onDropViewInstance(view: MapView) {
    view.destroy()
    super.onDropViewInstance(view)
  }

  @ReactProp(name = "provider")
  override fun setProvider(view: MapView, value: String?) {
    // Fabric schema reserves future providers; the current native implementation is AMap only.
  }

  @ReactProp(name = "coordinateSystem")
  override fun setCoordinateSystem(view: MapView, value: String?) {
    // JS normalizes coordinates before they cross the native boundary.
  }

  @ReactProp(name = "initialRegion")
  override fun setInitialRegion(view: MapView, value: ReadableMap?) {
    view.setInitialRegion(value?.toMapRegion())
  }

  @ReactProp(name = "region")
  override fun setRegion(view: MapView, value: ReadableMap?) {
    view.setRegion(value?.toMapRegion())
  }

  @ReactProp(name = "markers")
  override fun setMarkers(view: MapView, value: ReadableArray?) {
    view.setMarkers(value)
  }

  @ReactProp(name = "showsUserLocation")
  override fun setShowsUserLocation(view: MapView, value: Boolean) {
    view.setShowsUserLocation(value)
  }

  @ReactProp(name = "zoomEnabled")
  override fun setZoomEnabled(view: MapView, value: Boolean) {
    view.setZoomEnabled(value)
  }

  @ReactProp(name = "scrollEnabled")
  override fun setScrollEnabled(view: MapView, value: Boolean) {
    view.setScrollEnabled(value)
  }

  @ReactProp(name = "rotateEnabled")
  override fun setRotateEnabled(view: MapView, value: Boolean) {
    view.setRotateEnabled(value)
  }

  @ReactProp(name = "pitchEnabled")
  override fun setPitchEnabled(view: MapView, value: Boolean) {
    view.setPitchEnabled(value)
  }

  override fun animateToRegion(
    view: MapView,
    latitude: Double,
    longitude: Double,
    latitudeDelta: Double,
    longitudeDelta: Double,
    duration: Int
  ) {
    view.animateToRegion(
      MapRegion(
        latitude = latitude,
        longitude = longitude,
        latitudeDelta = latitudeDelta,
        longitudeDelta = longitudeDelta
      ),
      duration
    )
  }

  private fun ReadableMap.toMapRegion(): MapRegion {
    return MapRegion(
      latitude = getDouble("latitude"),
      longitude = getDouble("longitude"),
      latitudeDelta = getDouble("latitudeDelta"),
      longitudeDelta = getDouble("longitudeDelta")
    )
  }

  companion object {
    const val REACT_CLASS = "RNMapsMapView"
  }
}
