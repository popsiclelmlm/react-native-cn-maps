package com.cnmaps

import android.graphics.Point
import android.location.Location
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import com.amap.api.maps.AMap
import com.amap.api.maps.CameraUpdate
import com.amap.api.maps.CameraUpdateFactory
import com.amap.api.maps.MapView as AMapView
import com.amap.api.maps.model.CameraPosition
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.LatLngBounds
import com.amap.api.maps.model.Marker
import com.amap.api.maps.model.Poi
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min

data class MapRegion(
  val latitude: Double,
  val longitude: Double,
  val latitudeDelta: Double,
  val longitudeDelta: Double
)

// Flattened to scalars to mirror the codegen `NativeCamera` struct; JS rebuilds
// the RNM `{ center: LatLng }` shape on the way in/out.
data class MapCamera(
  val latitude: Double,
  val longitude: Double,
  val heading: Double,
  val pitch: Double,
  val zoom: Double,
  val altitude: Double
)

class MapView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext),
  LifecycleEventListener {
  private val mapView = AMapView(reactContext)
  private val aMap: AMap
  // Child host components (<Marker> et al.) mounted under this map. Fabric
  // reconciles them through the manager's ViewGroup overrides, which delegate to
  // addFeature/removeFeatureAt/getFeature* here. They are NOT added to the
  // FrameLayout — only the AMap surface is.
  private val features = ArrayList<View>()
  private val gestureDetector: GestureDetector
  private var pendingInitialRegion: MapRegion? = null
  private var pendingInitialCamera: MapCamera? = null
  private var didApplyInitialRegion = false
  private var didApplyInitialCamera = false
  private var didDestroy = false
  private var isGesture = false
  private var mapTypeProp: String? = null
  private var userInterfaceStyleProp: String? = null

  init {
    addView(mapView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    mapView.onCreate(null)
    aMap = mapView.map
    gestureDetector = GestureDetector(reactContext, GestureListener())
    reactContext.addLifecycleEventListener(this)
    configureMap()
  }

  fun setInitialRegion(region: MapRegion?) {
    if (region == null || didApplyInitialRegion || didApplyInitialCamera) {
      return
    }

    pendingInitialRegion = region
    applyPendingInitialCamera()
  }

  fun setRegion(region: MapRegion?) {
    if (region != null) {
      moveToRegion(region, animated = false)
    }
  }

  fun setInitialCamera(camera: MapCamera?) {
    if (camera == null || didApplyInitialCamera) {
      return
    }

    pendingInitialCamera = camera
    applyPendingInitialCamera()
  }

  fun setCamera(camera: MapCamera?) {
    if (camera != null) {
      moveToCamera(camera, animated = false)
    }
  }

  fun animateToRegion(region: MapRegion, duration: Int) {
    moveToRegion(region, animated = true, duration = duration)
  }

  // Imperative commands (M6) ---------------------------------------------------

  fun applyCamera(camera: MapCamera, animated: Boolean, duration: Int) {
    // A zero/zero center means "keep current center".
    val resolved = if (camera.latitude == 0.0 && camera.longitude == 0.0) {
      val target = aMap.cameraPosition.target
      camera.copy(latitude = target.latitude, longitude = target.longitude)
    } else {
      camera
    }
    moveToCamera(resolved, animated, duration)
  }

  fun fitToCoordinates(coordinatesJSON: String?, edgePaddingJSON: String?, animated: Boolean) {
    val bounds = boundsFromJSON(coordinatesJSON) ?: return
    applyBounds(bounds, edgePaddingJSON, animated)
  }

  fun fitToElements(animated: Boolean) {
    val builder = LatLngBounds.Builder()
    var any = false
    features.forEach { if (it is MarkerView) { builder.include(it.position()); any = true } }
    if (any) {
      applyBounds(builder.build(), null, animated)
    }
  }

  fun fitToSuppliedMarkers(markerIDsJSON: String?, edgePaddingJSON: String?, animated: Boolean) {
    val ids = runCatching {
      val arr = JSONArray(markerIDsJSON ?: "[]")
      (0 until arr.length()).map { arr.getString(it) }.toSet()
    }.getOrDefault(emptySet())
    if (ids.isEmpty()) {
      return
    }

    val builder = LatLngBounds.Builder()
    var any = false
    features.forEach {
      if (it is MarkerView && it.identifier != null && ids.contains(it.identifier)) {
        builder.include(it.position())
        any = true
      }
    }
    if (any) {
      applyBounds(builder.build(), edgePaddingJSON, animated)
    }
  }

  fun getCameraResult(requestId: Int) {
    val position = aMap.cameraPosition
    dispatchCommandResult(
      requestId,
      JSONObject()
        .put("latitude", position.target.latitude)
        .put("longitude", position.target.longitude)
        .put("heading", position.bearing.toDouble())
        .put("pitch", position.tilt.toDouble())
        .put("zoom", position.zoom.toDouble())
        .put("altitude", 0.0)
    )
  }

  fun getMapBoundariesResult(requestId: Int) {
    val bounds = runCatching { aMap.projection.visibleRegion.latLngBounds }.getOrNull()
    val data = JSONObject()
    if (bounds != null) {
      data.put(
        "northEast",
        JSONObject()
          .put("latitude", bounds.northeast.latitude)
          .put("longitude", bounds.northeast.longitude)
      )
      data.put(
        "southWest",
        JSONObject()
          .put("latitude", bounds.southwest.latitude)
          .put("longitude", bounds.southwest.longitude)
      )
    }
    dispatchCommandResult(requestId, data)
  }

  fun pointForCoordinateResult(requestId: Int, latitude: Double, longitude: Double) {
    val density = resources.displayMetrics.density
    val point = runCatching {
      aMap.projection.toScreenLocation(LatLng(latitude, longitude))
    }.getOrNull()
    dispatchCommandResult(
      requestId,
      JSONObject()
        .put("x", (point?.x ?: 0) / density)
        .put("y", (point?.y ?: 0) / density)
    )
  }

  fun coordinateForPointResult(requestId: Int, x: Double, y: Double) {
    val density = resources.displayMetrics.density
    val coordinate = runCatching {
      aMap.projection.fromScreenLocation(Point((x * density).toInt(), (y * density).toInt()))
    }.getOrNull()
    dispatchCommandResult(
      requestId,
      JSONObject()
        .put("latitude", coordinate?.latitude ?: 0.0)
        .put("longitude", coordinate?.longitude ?: 0.0)
    )
  }

  private fun applyBounds(bounds: LatLngBounds, edgePaddingJSON: String?, animated: Boolean) {
    val density = resources.displayMetrics.density
    val padding = runCatching {
      val o = JSONObject(edgePaddingJSON ?: "{}")
      val max = maxOf(
        o.optDouble("top", 0.0),
        o.optDouble("left", 0.0),
        o.optDouble("bottom", 0.0),
        o.optDouble("right", 0.0)
      )
      (max * density).toInt()
    }.getOrDefault(0)

    val update = CameraUpdateFactory.newLatLngBounds(bounds, padding)
    val apply = Runnable { applyCameraUpdate(update, animated, 300) }
    if (width <= 0 || height <= 0) post(apply) else apply.run()
  }

  private fun boundsFromJSON(json: String?): LatLngBounds? {
    return runCatching {
      val arr = JSONArray(json ?: "[]")
      if (arr.length() == 0) {
        return null
      }
      val builder = LatLngBounds.Builder()
      for (i in 0 until arr.length()) {
        val o = arr.getJSONObject(i)
        builder.include(LatLng(o.getDouble("latitude"), o.getDouble("longitude")))
      }
      builder.build()
    }.getOrNull()
  }

  private fun dispatchCommandResult(requestId: Int, data: JSONObject) {
    dispatchEvent(CommandResultEvent(surfaceId(), id, requestId, data.toString()))
  }

  // Child host-component management (called from the ViewGroupManager) ---------

  fun addFeature(child: View, index: Int) {
    when (child) {
      is MarkerView -> child.attachTo(aMap)
      is PolylineView -> child.attachTo(aMap)
      is PolygonView -> child.attachTo(aMap)
      is CircleView -> child.attachTo(aMap)
      is UrlTileView -> child.attachTo(aMap)
      is LocalTileView -> child.attachTo(aMap)
      is OverlayView -> child.attachTo(aMap)
      else -> return
    }
    features.add(index.coerceIn(0, features.size), child)
  }

  fun removeFeatureAt(index: Int) {
    if (index < 0 || index >= features.size) {
      return
    }

    when (val child = features.removeAt(index)) {
      is MarkerView -> child.detach()
      is PolylineView -> child.detach()
      is PolygonView -> child.detach()
      is CircleView -> child.detach()
      is UrlTileView -> child.detach()
      is LocalTileView -> child.detach()
      is OverlayView -> child.detach()
    }
  }

  fun getFeatureCount(): Int = features.size

  fun getFeatureAt(index: Int): View = features[index]

  // Appearance ----------------------------------------------------------------

  fun setMapType(mapType: String?) {
    mapTypeProp = mapType
    applyMapType()
  }

  fun setUserInterfaceStyle(userInterfaceStyle: String?) {
    userInterfaceStyleProp = userInterfaceStyle
    applyMapType()
  }

  private fun applyMapType() {
    // AMap Android has no dedicated hybrid/terrain/none surface; everything that
    // is not explicitly satellite collapses to the standard basemap (best-effort).
    aMap.mapType = when {
      mapTypeProp == "satellite" || mapTypeProp == "hybrid" -> AMap.MAP_TYPE_SATELLITE
      userInterfaceStyleProp == "dark" -> AMap.MAP_TYPE_NIGHT
      else -> AMap.MAP_TYPE_NORMAL
    }
  }

  // Zoom ----------------------------------------------------------------------

  fun setMinZoomLevel(value: Double) {
    aMap.minZoomLevel = value.toFloat()
  }

  fun setMaxZoomLevel(value: Double) {
    aMap.maxZoomLevel = value.toFloat()
  }

  // Gesture toggles -----------------------------------------------------------

  fun setZoomEnabled(value: Boolean) {
    aMap.uiSettings.isZoomGesturesEnabled = value
  }

  fun setZoomControlEnabled(value: Boolean) {
    aMap.uiSettings.isZoomControlsEnabled = value
  }

  fun setScrollEnabled(value: Boolean) {
    aMap.uiSettings.isScrollGesturesEnabled = value
  }

  fun setRotateEnabled(value: Boolean) {
    aMap.uiSettings.isRotateGesturesEnabled = value
  }

  fun setPitchEnabled(value: Boolean) {
    aMap.uiSettings.isTiltGesturesEnabled = value
  }

  // Display toggles -----------------------------------------------------------

  fun setShowsUserLocation(value: Boolean) {
    aMap.isMyLocationEnabled = value
  }

  fun setShowsMyLocationButton(value: Boolean) {
    aMap.uiSettings.isMyLocationButtonEnabled = value
  }

  fun setShowsCompass(value: Boolean) {
    aMap.uiSettings.isCompassEnabled = value
  }

  fun setShowsScale(value: Boolean) {
    aMap.uiSettings.isScaleControlsEnabled = value
  }

  fun setShowsTraffic(value: Boolean) {
    aMap.isTrafficEnabled = value
  }

  fun setShowsBuildings(value: Boolean) {
    aMap.showBuildings(value)
  }

  fun setShowsIndoors(value: Boolean) {
    aMap.showIndoorMap(value)
  }

  fun setShowsIndoorLevelPicker(value: Boolean) {
    aMap.uiSettings.isIndoorSwitchEnabled = value
  }

  fun setShowsPointsOfInterest(value: Boolean) {
    aMap.showMapText(value)
  }

  fun destroy() {
    if (didDestroy) {
      return
    }

    didDestroy = true
    reactContext.removeLifecycleEventListener(this)
    features.forEach { child ->
      when (child) {
        is MarkerView -> child.detach()
        is PolylineView -> child.detach()
        is PolygonView -> child.detach()
        is CircleView -> child.detach()
        is UrlTileView -> child.detach()
        is LocalTileView -> child.detach()
        is OverlayView -> child.detach()
      }
    }
    features.clear()
    mapView.onDestroy()
  }

  override fun onHostResume() {
    if (!didDestroy) {
      mapView.onResume()
    }
  }

  override fun onHostPause() {
    if (!didDestroy) {
      mapView.onPause()
    }
  }

  override fun onHostDestroy() {
    destroy()
  }

  override fun onSizeChanged(width: Int, height: Int, oldWidth: Int, oldHeight: Int) {
    super.onSizeChanged(width, height, oldWidth, oldHeight)
    applyPendingInitialCamera()
  }

  private fun configureMap() {
    aMap.uiSettings.isZoomControlsEnabled = false

    // onPanDrag / onDoublePress have no first-class AMap callback, so they ride
    // on a GestureDetector fed by the raw touch stream (alongside AMap's own
    // gesture handling — the touch listener is observe-only).
    aMap.setOnMapTouchListener { event ->
      if (event != null) {
        if (
          event.actionMasked == MotionEvent.ACTION_DOWN ||
          event.actionMasked == MotionEvent.ACTION_MOVE
        ) {
          isGesture = true
        }
        gestureDetector.onTouchEvent(event)
      }
    }

    aMap.setOnCameraChangeListener(
      object : AMap.OnCameraChangeListener {
        override fun onCameraChange(position: CameraPosition?) {
          sendRegionEvent("topRegionChange", isGesture)
        }

        override fun onCameraChangeFinish(position: CameraPosition?) {
          sendRegionEvent("topRegionChangeComplete", isGesture)
          isGesture = false
        }
      }
    )

    aMap.setOnMapLoadedListener {
      dispatchEvent(SimpleEvent(surfaceId(), id, "topMapReady"))
      dispatchEvent(SimpleEvent(surfaceId(), id, "topMapLoaded"))
    }

    aMap.setOnMapClickListener { latLng ->
      latLng?.let { sendPressEvent("topPress", it) }
    }

    aMap.setOnMapLongClickListener { latLng ->
      latLng?.let { sendPressEvent("topLongPress", it) }
    }

    aMap.setOnPOIClickListener { poi ->
      poi?.let { sendPoiClickEvent(it) }
    }

    aMap.setOnMyLocationChangeListener { location ->
      location?.let { sendUserLocationChangeEvent(it) }
    }

    aMap.setOnMarkerClickListener { marker ->
      // The owning child MarkerView is stashed in marker.object; route the
      // map-level click back to it. RNM fires both onPress and onSelect.
      (marker.`object` as? MarkerView)?.let {
        it.emitPress()
        it.emitSelect()
      }
      false
    }

    aMap.setOnMarkerDragListener(
      object : AMap.OnMarkerDragListener {
        override fun onMarkerDragStart(marker: Marker?) {
          (marker?.`object` as? MarkerView)?.emitDragStart()
        }

        override fun onMarkerDrag(marker: Marker?) {
          (marker?.`object` as? MarkerView)?.emitDrag()
        }

        override fun onMarkerDragEnd(marker: Marker?) {
          (marker?.`object` as? MarkerView)?.emitDragEnd()
        }
      }
    )

    aMap.setOnInfoWindowClickListener { marker ->
      (marker?.`object` as? MarkerView)?.onInfoWindowClicked()
    }

    // Custom <Callout> content (M4): hand the marker's callout view to AMap as the
    // info window. Returning null falls back to the default title/snippet window.
    aMap.setInfoWindowAdapter(
      object : AMap.InfoWindowAdapter {
        override fun getInfoWindow(marker: Marker?): View? =
          (marker?.`object` as? MarkerView)?.getCalloutView()

        override fun getInfoContents(marker: Marker?): View? = null
      }
    )
  }

  private inner class GestureListener : GestureDetector.SimpleOnGestureListener() {
    override fun onDoubleTap(event: MotionEvent): Boolean {
      coordinateForTouch(event)?.let { sendPressEvent("topDoublePress", it, event.x, event.y) }
      return false
    }

    override fun onScroll(
      e1: MotionEvent?,
      e2: MotionEvent,
      distanceX: Float,
      distanceY: Float
    ): Boolean {
      coordinateForTouch(e2)?.let { sendPressEvent("topPanDrag", it, e2.x, e2.y) }
      return false
    }
  }

  private fun applyPendingInitialCamera() {
    if (width <= 0 || height <= 0) {
      return
    }

    pendingInitialRegion?.let { region ->
      pendingInitialRegion = null
      didApplyInitialRegion = true
      moveToRegion(region, animated = false)
    }

    // A camera takes precedence over a region (RNM semantics), so it is applied
    // last and overwrites the region setup.
    pendingInitialCamera?.let { camera ->
      pendingInitialCamera = null
      didApplyInitialCamera = true
      moveToCamera(camera, animated = false)
    }
  }

  private fun moveToRegion(region: MapRegion, animated: Boolean, duration: Int = 0) {
    val applyCamera = Runnable {
      val boundsUpdate = CameraUpdateFactory.newLatLngBounds(region.toBounds(), 0)
      runCatching {
        applyCameraUpdate(boundsUpdate, animated, duration)
      }.onFailure {
        val fallbackUpdate = CameraUpdateFactory.newLatLngZoom(
          LatLng(region.latitude, region.longitude),
          region.toApproximateZoom()
        )
        applyCameraUpdate(fallbackUpdate, animated, duration)
      }
    }

    if (width <= 0 || height <= 0) {
      post(applyCamera)
    } else {
      applyCamera.run()
    }
  }

  private fun moveToCamera(camera: MapCamera, animated: Boolean, duration: Int = 0) {
    val applyCamera = Runnable {
      // A zero/unset zoom means "keep current"; the flattened struct defaults to 0.
      val zoom = if (camera.zoom > 0) camera.zoom.toFloat() else aMap.cameraPosition.zoom
      val position = CameraPosition(
        LatLng(camera.latitude, camera.longitude),
        zoom,
        camera.pitch.toFloat(),
        camera.heading.toFloat()
      )
      applyCameraUpdate(CameraUpdateFactory.newCameraPosition(position), animated, duration)
    }

    if (width <= 0 || height <= 0) {
      post(applyCamera)
    } else {
      applyCamera.run()
    }
  }

  private fun applyCameraUpdate(update: CameraUpdate, animated: Boolean, duration: Int) {
    if (animated) {
      aMap.animateCamera(update, duration.toLong(), null)
    } else {
      aMap.moveCamera(update)
    }
  }

  private fun coordinateForTouch(event: MotionEvent): LatLng? {
    return runCatching {
      aMap.projection.fromScreenLocation(Point(event.x.toInt(), event.y.toInt()))
    }.getOrNull()
  }

  private fun screenPointFor(coordinate: LatLng): Point? {
    return runCatching {
      aMap.projection.toScreenLocation(coordinate)
    }.getOrNull()
  }

  private fun surfaceId(): Int = UIManagerHelper.getSurfaceId(this)

  private fun dispatchEvent(event: Event<*>) {
    if (id == NO_ID) {
      return
    }

    UIManagerHelper.getEventDispatcher(reactContext)?.dispatchEvent(event)
  }

  private fun sendRegionEvent(eventName: String, gesture: Boolean) {
    currentRegion()?.let { region ->
      dispatchEvent(RegionEvent(surfaceId(), id, eventName, region, gesture))
    }
  }

  private fun sendPressEvent(
    eventName: String,
    coordinate: LatLng,
    x: Float? = null,
    y: Float? = null
  ) {
    // Report the touch position in RN's coordinate space (dp), mirroring how
    // gesture coordinates flow through the JS facade untouched.
    val density = resources.displayMetrics.density
    val point = if (x != null && y != null) {
      Point(x.toInt(), y.toInt())
    } else {
      screenPointFor(coordinate)
    }

    dispatchEvent(
      PressEvent(
        surfaceId(),
        id,
        eventName,
        coordinate.latitude,
        coordinate.longitude,
        (point?.x ?: 0) / density,
        (point?.y ?: 0) / density
      )
    )
  }

  private fun sendPoiClickEvent(poi: Poi) {
    val coordinate = poi.coordinate ?: return
    val density = resources.displayMetrics.density
    val point = screenPointFor(coordinate)

    dispatchEvent(
      PoiClickEvent(
        surfaceId(),
        id,
        poi.poiId,
        poi.name,
        coordinate.latitude,
        coordinate.longitude,
        (point?.x ?: 0) / density,
        (point?.y ?: 0) / density
      )
    )
  }

  private fun sendUserLocationChangeEvent(location: Location) {
    dispatchEvent(UserLocationChangeEvent(surfaceId(), id, location))
  }

  private fun currentRegion(): MapRegion? {
    val bounds = runCatching {
      aMap.projection.visibleRegion.latLngBounds
    }.getOrNull() ?: return null
    val target = aMap.cameraPosition.target ?: return null
    val latitudeDelta = abs(bounds.northeast.latitude - bounds.southwest.latitude)
    val longitudeDelta = abs(bounds.northeast.longitude - bounds.southwest.longitude)

    return MapRegion(
      latitude = target.latitude,
      longitude = target.longitude,
      latitudeDelta = latitudeDelta,
      longitudeDelta = longitudeDelta
    )
  }

  private fun MapRegion.toBounds(): LatLngBounds {
    val halfLat = max(latitudeDelta, MIN_DELTA) / 2.0
    val halfLon = max(longitudeDelta, MIN_DELTA) / 2.0
    val southwest = LatLng(
      max(-90.0, latitude - halfLat),
      max(-180.0, longitude - halfLon)
    )
    val northeast = LatLng(
      min(90.0, latitude + halfLat),
      min(180.0, longitude + halfLon)
    )

    return LatLngBounds(southwest, northeast)
  }

  private fun MapRegion.toApproximateZoom(): Float {
    val delta = max(max(latitudeDelta, longitudeDelta), MIN_DELTA)
    val zoom = ln(360.0 / delta) / ln(2.0)
    return zoom.toFloat().coerceIn(3f, 20f)
  }

  private class RegionEvent(
    surfaceId: Int,
    viewId: Int,
    private val rnEventName: String,
    private val region: MapRegion,
    private val isGesture: Boolean
  ) : Event<RegionEvent>(surfaceId, viewId) {
    override fun getEventName(): String = rnEventName

    override fun getEventData(): WritableMap =
      Arguments.createMap().apply {
        putMap(
          "region",
          Arguments.createMap().apply {
            putDouble("latitude", region.latitude)
            putDouble("longitude", region.longitude)
            putDouble("latitudeDelta", region.latitudeDelta)
            putDouble("longitudeDelta", region.longitudeDelta)
          }
        )
        putBoolean("isGesture", isGesture)
      }
  }

  // M6 query result: JSON payload keyed by the JS request id.
  private class CommandResultEvent(
    surfaceId: Int,
    viewId: Int,
    private val requestId: Int,
    private val data: String
  ) : Event<CommandResultEvent>(surfaceId, viewId) {
    override fun getEventName(): String = "topCommandResult"

    override fun canCoalesce(): Boolean = false

    override fun getEventData(): WritableMap =
      Arguments.createMap().apply {
        putInt("id", requestId)
        putString("data", data)
      }
  }

  // onMapReady / onMapLoaded carry no payload.
  private class SimpleEvent(
    surfaceId: Int,
    viewId: Int,
    private val rnEventName: String
  ) : Event<SimpleEvent>(surfaceId, viewId) {
    override fun getEventName(): String = rnEventName

    override fun getEventData(): WritableMap = Arguments.createMap()
  }

  // Shared by onPress / onLongPress / onDoublePress / onPanDrag.
  private class PressEvent(
    surfaceId: Int,
    viewId: Int,
    private val rnEventName: String,
    private val latitude: Double,
    private val longitude: Double,
    private val x: Float,
    private val y: Float
  ) : Event<PressEvent>(surfaceId, viewId) {
    override fun getEventName(): String = rnEventName

    override fun canCoalesce(): Boolean = rnEventName == "topPanDrag"

    override fun getEventData(): WritableMap =
      Arguments.createMap().apply {
        putMap(
          "coordinate",
          Arguments.createMap().apply {
            putDouble("latitude", latitude)
            putDouble("longitude", longitude)
          }
        )
        putMap(
          "position",
          Arguments.createMap().apply {
            putDouble("x", x.toDouble())
            putDouble("y", y.toDouble())
          }
        )
      }
  }

  private class PoiClickEvent(
    surfaceId: Int,
    viewId: Int,
    private val placeId: String?,
    private val name: String?,
    private val latitude: Double,
    private val longitude: Double,
    private val x: Float,
    private val y: Float
  ) : Event<PoiClickEvent>(surfaceId, viewId) {
    override fun getEventName(): String = "topPoiClick"

    override fun canCoalesce(): Boolean = false

    override fun getEventData(): WritableMap =
      Arguments.createMap().apply {
        placeId?.let { putString("placeId", it) }
        name?.let { putString("name", it) }
        putMap(
          "coordinate",
          Arguments.createMap().apply {
            putDouble("latitude", latitude)
            putDouble("longitude", longitude)
          }
        )
        putMap(
          "position",
          Arguments.createMap().apply {
            putDouble("x", x.toDouble())
            putDouble("y", y.toDouble())
          }
        )
      }
  }

  private class UserLocationChangeEvent(
    surfaceId: Int,
    viewId: Int,
    private val location: Location
  ) : Event<UserLocationChangeEvent>(surfaceId, viewId) {
    override fun getEventName(): String = "topUserLocationChange"

    override fun canCoalesce(): Boolean = false

    override fun getEventData(): WritableMap =
      Arguments.createMap().apply {
        putMap(
          "coordinate",
          Arguments.createMap().apply {
            putDouble("latitude", location.latitude)
            putDouble("longitude", location.longitude)
            putDouble("altitude", location.altitude)
            putDouble("accuracy", location.accuracy.toDouble())
            putDouble("speed", location.speed.toDouble())
            putDouble("heading", location.bearing.toDouble())
            putBoolean("isFromMockProvider", location.isFromMockProvider)
          }
        )
      }
  }

  private companion object {
    private const val MIN_DELTA = 0.000001
  }
}
