package com.cnmaps

import android.view.View
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNMapsMapViewManagerDelegate
import com.facebook.react.viewmanagers.RNMapsMapViewManagerInterface

// ViewGroupManager (not SimpleViewManager) so Fabric mounts <Marker> children as
// real child host components: addView/removeViewAt/getChild* below redirect them
// to MapView's internal feature list instead of the FrameLayout.
@ReactModule(name = MapViewManager.REACT_CLASS)
class MapViewManager : ViewGroupManager<MapView>(),
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

  // Child host-component plumbing. Fabric's SurfaceMountingManager reconciles
  // children through these manager hooks; getChildCount/getChildAt MUST mirror
  // exactly what add/removeView leaves behind or it crashes with "view not
  // found". MapView keeps the backing list (the AMap surface is hidden from it).

  override fun addView(parent: MapView, child: View, index: Int) {
    parent.addFeature(child, index)
  }

  override fun removeViewAt(parent: MapView, index: Int) {
    parent.removeFeatureAt(index)
  }

  override fun getChildCount(parent: MapView): Int = parent.getFeatureCount()

  override fun getChildAt(parent: MapView, index: Int): View = parent.getFeatureAt(index)

  @ReactProp(name = "provider")
  override fun setProvider(view: MapView, value: String?) {
    // Fabric schema reserves future providers; the current native implementation is AMap only.
  }

  @ReactProp(name = "coordinateSystem")
  override fun setCoordinateSystem(view: MapView, value: String?) {
    // JS normalizes coordinates before they cross the native boundary.
  }

  // Region / camera -----------------------------------------------------------

  @ReactProp(name = "initialRegion")
  override fun setInitialRegion(view: MapView, value: ReadableMap?) {
    view.setInitialRegion(value?.toMapRegion())
  }

  @ReactProp(name = "region")
  override fun setRegion(view: MapView, value: ReadableMap?) {
    view.setRegion(value?.toMapRegion())
  }

  @ReactProp(name = "initialCamera")
  override fun setInitialCamera(view: MapView, value: ReadableMap?) {
    view.setInitialCamera(value?.toMapCamera())
  }

  @ReactProp(name = "camera")
  override fun setCamera(view: MapView, value: ReadableMap?) {
    view.setCamera(value?.toMapCamera())
  }

  // Appearance ----------------------------------------------------------------

  @ReactProp(name = "mapType")
  override fun setMapType(view: MapView, value: String?) {
    view.setMapType(value)
  }

  @ReactProp(name = "userInterfaceStyle")
  override fun setUserInterfaceStyle(view: MapView, value: String?) {
    view.setUserInterfaceStyle(value)
  }

  @ReactProp(name = "customMapStyle")
  override fun setCustomMapStyle(view: MapView, value: String?) {
    // RNM ships a Google-flavored style JSON that AMap cannot consume; the JS
    // facade warns. Honoring it requires an AMap binary style and is deferred.
  }

  @ReactProp(name = "tintColor", customType = "Color")
  override fun setTintColor(view: MapView, value: Int?) {
    // No global tint surface on AMap Android; best-effort ignore.
  }

  @ReactProp(name = "mapPadding")
  override fun setMapPadding(view: MapView, value: ReadableMap?) {
    // AMap Android exposes no map-content padding API; best-effort ignore.
  }

  @ReactProp(name = "kmlSrc")
  override fun setKmlSrc(view: MapView, value: String?) {
    // KML import is not part of the M2 surface; best-effort ignore.
  }

  // Zoom ----------------------------------------------------------------------

  @ReactProp(name = "minZoomLevel", defaultDouble = 3.0)
  override fun setMinZoomLevel(view: MapView, value: Double) {
    view.setMinZoomLevel(value)
  }

  @ReactProp(name = "maxZoomLevel", defaultDouble = 20.0)
  override fun setMaxZoomLevel(view: MapView, value: Double) {
    view.setMaxZoomLevel(value)
  }

  // Gesture toggles -----------------------------------------------------------

  @ReactProp(name = "zoomEnabled", defaultBoolean = true)
  override fun setZoomEnabled(view: MapView, value: Boolean) {
    view.setZoomEnabled(value)
  }

  @ReactProp(name = "zoomTapEnabled", defaultBoolean = true)
  override fun setZoomTapEnabled(view: MapView, value: Boolean) {
    // AMap Android folds double-tap-to-zoom into the zoom gesture toggle; no
    // independent switch exists. Best-effort ignore.
  }

  @ReactProp(name = "zoomControlEnabled", defaultBoolean = false)
  override fun setZoomControlEnabled(view: MapView, value: Boolean) {
    view.setZoomControlEnabled(value)
  }

  @ReactProp(name = "scrollEnabled", defaultBoolean = true)
  override fun setScrollEnabled(view: MapView, value: Boolean) {
    view.setScrollEnabled(value)
  }

  @ReactProp(name = "scrollDuringRotateOrZoomEnabled", defaultBoolean = true)
  override fun setScrollDuringRotateOrZoomEnabled(view: MapView, value: Boolean) {
    // No dedicated AMap toggle; best-effort ignore.
  }

  @ReactProp(name = "rotateEnabled", defaultBoolean = true)
  override fun setRotateEnabled(view: MapView, value: Boolean) {
    view.setRotateEnabled(value)
  }

  @ReactProp(name = "pitchEnabled", defaultBoolean = true)
  override fun setPitchEnabled(view: MapView, value: Boolean) {
    view.setPitchEnabled(value)
  }

  // Display toggles -----------------------------------------------------------

  @ReactProp(name = "showsUserLocation", defaultBoolean = false)
  override fun setShowsUserLocation(view: MapView, value: Boolean) {
    view.setShowsUserLocation(value)
  }

  @ReactProp(name = "showsMyLocationButton", defaultBoolean = true)
  override fun setShowsMyLocationButton(view: MapView, value: Boolean) {
    view.setShowsMyLocationButton(value)
  }

  @ReactProp(name = "showsCompass", defaultBoolean = true)
  override fun setShowsCompass(view: MapView, value: Boolean) {
    view.setShowsCompass(value)
  }

  @ReactProp(name = "showsScale", defaultBoolean = false)
  override fun setShowsScale(view: MapView, value: Boolean) {
    view.setShowsScale(value)
  }

  @ReactProp(name = "showsTraffic", defaultBoolean = false)
  override fun setShowsTraffic(view: MapView, value: Boolean) {
    view.setShowsTraffic(value)
  }

  @ReactProp(name = "showsBuildings", defaultBoolean = true)
  override fun setShowsBuildings(view: MapView, value: Boolean) {
    view.setShowsBuildings(value)
  }

  @ReactProp(name = "showsIndoors", defaultBoolean = true)
  override fun setShowsIndoors(view: MapView, value: Boolean) {
    view.setShowsIndoors(value)
  }

  @ReactProp(name = "showsIndoorLevelPicker", defaultBoolean = false)
  override fun setShowsIndoorLevelPicker(view: MapView, value: Boolean) {
    view.setShowsIndoorLevelPicker(value)
  }

  @ReactProp(name = "showsPointsOfInterest", defaultBoolean = true)
  override fun setShowsPointsOfInterest(view: MapView, value: Boolean) {
    view.setShowsPointsOfInterest(value)
  }

  // Loading state -------------------------------------------------------------

  @ReactProp(name = "loadingEnabled", defaultBoolean = false)
  override fun setLoadingEnabled(view: MapView, value: Boolean) {
    // AMap renders its own tile-loading state; no RN loading overlay for M2.
  }

  @ReactProp(name = "loadingIndicatorColor", customType = "Color")
  override fun setLoadingIndicatorColor(view: MapView, value: Int?) {
    // Tied to the (unimplemented) loading overlay; best-effort ignore.
  }

  @ReactProp(name = "loadingBackgroundColor", customType = "Color")
  override fun setLoadingBackgroundColor(view: MapView, value: Int?) {
    // Tied to the (unimplemented) loading overlay; best-effort ignore.
  }

  // Android-only flags reserved by the shared schema --------------------------

  @ReactProp(name = "toolbarEnabled", defaultBoolean = true)
  override fun setToolbarEnabled(view: MapView, value: Boolean) {
    // The Google Maps map toolbar has no AMap equivalent; best-effort ignore.
  }

  @ReactProp(name = "liteMode", defaultBoolean = false)
  override fun setLiteMode(view: MapView, value: Boolean) {
    // Lite mode is a Google Maps concept; best-effort ignore.
  }

  @ReactProp(name = "cacheEnabled", defaultBoolean = false)
  override fun setCacheEnabled(view: MapView, value: Boolean) {
    // Snapshot caching is a Google Maps concept; best-effort ignore.
  }

  // Commands ------------------------------------------------------------------

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

  private fun ReadableMap.toMapCamera(): MapCamera {
    return MapCamera(
      latitude = optDouble("latitude"),
      longitude = optDouble("longitude"),
      heading = optDouble("heading"),
      pitch = optDouble("pitch"),
      zoom = optDouble("zoom"),
      altitude = optDouble("altitude")
    )
  }

  private fun ReadableMap.optDouble(key: String): Double {
    return if (hasKey(key) && !isNull(key)) getDouble(key) else 0.0
  }

  companion object {
    const val REACT_CLASS = "RNMapsMapView"
  }
}
