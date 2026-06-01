package com.cnmaps

import android.graphics.Color
import android.view.MotionEvent
import android.widget.FrameLayout
import com.amap.api.maps.AMap
import com.amap.api.maps.CameraUpdate
import com.amap.api.maps.CameraUpdateFactory
import com.amap.api.maps.MapView as AMapView
import com.amap.api.maps.model.BitmapDescriptorFactory
import com.amap.api.maps.model.CameraPosition
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.LatLngBounds
import com.amap.api.maps.model.Marker
import com.amap.api.maps.model.MarkerOptions
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
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

class MapView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext),
  LifecycleEventListener {
  private val mapView = AMapView(reactContext)
  private val aMap: AMap
  private val markerByIdentifier = LinkedHashMap<String, Marker>()
  private var pendingInitialRegion: MapRegion? = null
  private var didApplyInitialRegion = false
  private var didDestroy = false
  private var isGesture = false

  init {
    addView(mapView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    mapView.onCreate(null)
    aMap = mapView.map
    reactContext.addLifecycleEventListener(this)
    configureMap()
  }

  fun setInitialRegion(region: MapRegion?) {
    if (region == null || didApplyInitialRegion) {
      return
    }

    pendingInitialRegion = region
    applyPendingInitialRegion()
  }

  fun setRegion(region: MapRegion?) {
    if (region != null) {
      moveToRegion(region, animated = false)
    }
  }

  fun animateToRegion(region: MapRegion, duration: Int) {
    moveToRegion(region, animated = true, duration = duration)
  }

  fun setMarkers(markers: ReadableArray?) {
    markerByIdentifier.values.forEach { it.remove() }
    markerByIdentifier.clear()

    if (markers == null) {
      return
    }

    for (index in 0 until markers.size()) {
      val markerMap = markers.getMap(index) ?: continue
      val identifier = markerMap.getOptionalString("identifier") ?: index.toString()
      val latitude = markerMap.getOptionalDouble("latitude") ?: continue
      val longitude = markerMap.getOptionalDouble("longitude") ?: continue

      val options = MarkerOptions()
        .position(LatLng(latitude, longitude))
        .draggable(markerMap.getOptionalBoolean("draggable") ?: false)

      markerMap.getOptionalString("title")?.let { options.title(it) }
      markerMap.getOptionalString("description")?.let { options.snippet(it) }
      markerMap.getOptionalString("pinColor")?.let { pinColor ->
        markerHue(pinColor)?.let { hue ->
          options.icon(BitmapDescriptorFactory.defaultMarker(hue))
        }
      }

      val marker = aMap.addMarker(options)
      marker.`object` = identifier
      markerByIdentifier[identifier] = marker
    }
  }

  fun setShowsUserLocation(value: Boolean) {
    aMap.isMyLocationEnabled = value
  }

  fun setZoomEnabled(value: Boolean) {
    aMap.uiSettings.isZoomGesturesEnabled = value
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

  fun destroy() {
    if (didDestroy) {
      return
    }

    didDestroy = true
    reactContext.removeLifecycleEventListener(this)
    markerByIdentifier.values.forEach { it.remove() }
    markerByIdentifier.clear()
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
    applyPendingInitialRegion()
  }

  private fun configureMap() {
    aMap.uiSettings.isZoomControlsEnabled = false

    aMap.setOnMapTouchListener { event ->
      if (
        event?.actionMasked == MotionEvent.ACTION_DOWN ||
        event?.actionMasked == MotionEvent.ACTION_MOVE
      ) {
        isGesture = true
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

    aMap.setOnMarkerClickListener { marker ->
      val identifier = marker.`object` as? String ?: return@setOnMarkerClickListener false
      sendMarkerPressEvent(identifier, marker.position)
      false
    }
  }

  private fun applyPendingInitialRegion() {
    val region = pendingInitialRegion ?: return

    if (width <= 0 || height <= 0) {
      return
    }

    didApplyInitialRegion = true
    pendingInitialRegion = null
    moveToRegion(region, animated = false)
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

  private fun applyCameraUpdate(update: CameraUpdate, animated: Boolean, duration: Int) {
    if (animated) {
      aMap.animateCamera(update, duration.toLong(), null)
    } else {
      aMap.moveCamera(update)
    }
  }

  private fun sendRegionEvent(eventName: String, gesture: Boolean) {
    if (id == NO_ID) {
      return
    }

    currentRegion()?.let { region ->
      UIManagerHelper.getEventDispatcher(reactContext)
        ?.dispatchEvent(RegionEvent(UIManagerHelper.getSurfaceId(this), id, eventName, region, gesture))
    }
  }

  private fun sendMarkerPressEvent(identifier: String, coordinate: LatLng) {
    if (id == NO_ID) {
      return
    }

    UIManagerHelper.getEventDispatcher(reactContext)
      ?.dispatchEvent(
        MarkerPressEvent(
          UIManagerHelper.getSurfaceId(this),
          id,
          identifier,
          coordinate.latitude,
          coordinate.longitude
        )
      )
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

  private fun markerHue(color: String): Float? {
    return runCatching {
      val hsv = FloatArray(3)
      Color.colorToHSV(Color.parseColor(color), hsv)
      hsv[0]
    }.getOrNull()
  }

  private fun ReadableMap.getOptionalString(key: String): String? {
    return if (hasKey(key) && !isNull(key)) getString(key) else null
  }

  private fun ReadableMap.getOptionalDouble(key: String): Double? {
    return if (hasKey(key) && !isNull(key)) getDouble(key) else null
  }

  private fun ReadableMap.getOptionalBoolean(key: String): Boolean? {
    return if (hasKey(key) && !isNull(key)) getBoolean(key) else null
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

  private class MarkerPressEvent(
    surfaceId: Int,
    viewId: Int,
    private val identifier: String,
    private val latitude: Double,
    private val longitude: Double
  ) : Event<MarkerPressEvent>(surfaceId, viewId) {
    override fun getEventName(): String = "topMarkerPress"

    override fun canCoalesce(): Boolean = false

    override fun getEventData(): WritableMap =
      Arguments.createMap().apply {
        putString("identifier", identifier)
        putMap(
          "coordinate",
          Arguments.createMap().apply {
            putDouble("latitude", latitude)
            putDouble("longitude", longitude)
          }
        )
      }
  }

  private companion object {
    private const val MIN_DELTA = 0.000001
  }
}
