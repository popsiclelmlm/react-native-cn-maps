package com.cnmaps

import android.util.Log
import android.view.View
import android.widget.FrameLayout
import com.cnmaps.adapter.CnEdgeInsets
import com.cnmaps.adapter.CnLatLng
import com.cnmaps.adapter.CnMapAdapter
import com.cnmaps.adapter.CnMapAdapterDelegate
import com.cnmaps.adapter.CnMapAdapterRegistry
import com.cnmaps.adapter.CnMarkerEvent
import com.cnmaps.adapter.CnPoi
import com.cnmaps.adapter.CnPressKind
import com.cnmaps.adapter.CnRegion
import com.cnmaps.adapter.CnCamera
import com.cnmaps.adapter.CnUserLocation
import com.cnmaps.adapter.OverlayHandle
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import org.json.JSONArray
import org.json.JSONObject

// Provider-agnostic Fabric host. Owns the ViewGroup lifecycle, child routing and
// event dispatch; the map provider is encapsulated behind a CnMapAdapter obtained
// from the registry, so this file carries zero SDK references.
class MapView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext),
  LifecycleEventListener,
  CnMapHost,
  CnMapAdapterDelegate {

  private var adapter: CnMapAdapter? = null
  private var currentProvider: String? = null

  // Child host components (<Marker> et al.), in mount order. They are NOT added to
  // the FrameLayout — only the adapter's map surface is.
  private val features = ArrayList<View>()
  private val childrenById = HashMap<String, View>()
  private var childIdCounter = 0
  private var didDestroy = false

  init {
    // Start with the default provider; an explicit `provider` prop may switch it
    // (via the manager's setProvider) before any children mount.
    applyProvider(null)
    reactContext.addLifecycleEventListener(this)
  }

  // Select the adapter for `provider` ("amap"/"baidu"/"tencent") from the registry.
  // Provider is "mount-fixed" (JS remounts on change), so this is a no-op once a
  // matching adapter exists; the recreate path re-attaches any existing children.
  fun applyProvider(provider: String?) {
    val requested = provider?.takeIf { it.isNotEmpty() }
    if (adapter != null && (requested == null || currentProvider == requested)) {
      return
    }

    val old = adapter
    if (old != null) {
      features.forEach { detachFeatureFromAdapter(it, old) }
      removeView(old.view)
      old.onDestroy()
    }

    val created = CnMapAdapterRegistry.createAdapter(reactContext, requested)
    adapter = created
    if (created == null) {
      currentProvider = null
      Log.e(
        "RNMaps",
        "No map adapter registered for provider=${requested ?: "(default)"}. Install a provider " +
          "package (e.g. react-native-cn-maps-amap) so a map can be created."
      )
      return
    }
    currentProvider = created.providerName
    addView(created.view, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    created.delegate = this
    // Re-attach any existing children to the freshly created adapter.
    features.forEach { child ->
      when (child) {
        is MarkerView -> child.cnHandle = created.addMarker(child.markerModel(), child.cnChildId ?: nextChildId())
        is CnOverlayFeature -> child.cnHandle = created.addOverlay(child.overlayModel(), child.cnChildId ?: nextChildId())
      }
    }
  }

  private fun detachFeatureFromAdapter(child: View, target: CnMapAdapter) {
    when (child) {
      is MarkerView -> child.cnHandle?.let { target.removeMarker(it) }
      is CnOverlayFeature -> child.cnHandle?.let { target.removeOverlay(it) }
    }
  }

  // CnMapHost ------------------------------------------------------------------

  override val mapAdapter: CnMapAdapter? get() = adapter

  override fun onChildModelChanged(child: View) {
    when (child) {
      is MarkerView -> child.cnHandle?.let { adapter?.updateMarker(it, child.markerModel()) }
      is CnOverlayFeature -> child.cnHandle?.let { adapter?.updateOverlay(it, child.overlayModel()) }
    }
  }

  private fun nextChildId(): String = "cn-${++childIdCounter}"

  // Viewport / camera ----------------------------------------------------------

  fun setInitialRegion(region: CnRegion?) { region?.let { adapter?.setInitialRegion(it) } }
  fun setRegion(region: CnRegion?) { region?.let { adapter?.setRegion(it) } }
  fun setInitialCamera(camera: CnCamera?) { camera?.let { adapter?.setInitialCamera(it) } }
  fun setCamera(camera: CnCamera?) { camera?.let { adapter?.setCamera(it) } }
  fun animateToRegion(region: CnRegion, duration: Int) { adapter?.animateToRegion(region, duration) }
  fun applyCamera(camera: CnCamera, animated: Boolean, duration: Int) { adapter?.applyCamera(camera, animated, duration) }

  fun fitToCoordinates(coordinatesJSON: String?, edgePaddingJSON: String?, animated: Boolean) {
    val coords = coordinatesFromJSON(coordinatesJSON)
    if (coords.isEmpty()) return
    adapter?.fitToCoordinates(coords, edgeInsets(edgePaddingJSON), animated)
  }

  fun fitToElements(animated: Boolean) {
    val handles = features.filterIsInstance<MarkerView>().mapNotNull { it.cnHandle }
    if (handles.isNotEmpty()) adapter?.fitToMarkers(handles, CnEdgeInsets.ZERO, animated)
  }

  fun fitToSuppliedMarkers(markerIDsJSON: String?, edgePaddingJSON: String?, animated: Boolean) {
    val ids = runCatching {
      val arr = JSONArray(markerIDsJSON ?: "[]")
      (0 until arr.length()).map { arr.getString(it) }.toSet()
    }.getOrDefault(emptySet())
    if (ids.isEmpty()) return
    val handles = features.filterIsInstance<MarkerView>()
      .filter { it.identifier != null && ids.contains(it.identifier) }
      .mapNotNull { it.cnHandle }
    if (handles.isNotEmpty()) adapter?.fitToMarkers(handles, edgeInsets(edgePaddingJSON), animated)
  }

  fun setMapBoundariesValue(neLatitude: Double, neLongitude: Double, swLatitude: Double, swLongitude: Double) {
    adapter?.setMapBoundaries(CnLatLng(neLatitude, neLongitude), CnLatLng(swLatitude, swLongitude))
  }

  // Query commands -------------------------------------------------------------

  fun getCameraResult(requestId: Int) {
    val camera = adapter?.currentCamera() ?: return dispatchCommandResult(requestId, JSONObject())
    dispatchCommandResult(
      requestId,
      JSONObject()
        .put("latitude", camera.latitude)
        .put("longitude", camera.longitude)
        .put("heading", camera.heading)
        .put("pitch", camera.pitch)
        .put("zoom", camera.zoom)
        .put("altitude", camera.altitude)
    )
  }

  fun getMapBoundariesResult(requestId: Int) {
    val bounds = adapter?.mapBoundaries()
    val data = JSONObject()
    if (bounds != null) {
      val (ne, sw) = bounds
      data.put("northEast", JSONObject().put("latitude", ne.latitude).put("longitude", ne.longitude))
      data.put("southWest", JSONObject().put("latitude", sw.latitude).put("longitude", sw.longitude))
    }
    dispatchCommandResult(requestId, data)
  }

  fun pointForCoordinateResult(requestId: Int, latitude: Double, longitude: Double) {
    val density = resources.displayMetrics.density
    val point = adapter?.pointForCoordinate(CnLatLng(latitude, longitude))
    dispatchCommandResult(
      requestId,
      JSONObject().put("x", (point?.x ?: 0) / density).put("y", (point?.y ?: 0) / density)
    )
  }

  fun coordinateForPointResult(requestId: Int, x: Double, y: Double) {
    val density = resources.displayMetrics.density
    val coordinate = adapter?.coordinateForPoint((x * density).toInt(), (y * density).toInt())
    dispatchCommandResult(
      requestId,
      JSONObject().put("latitude", coordinate?.latitude ?: 0.0).put("longitude", coordinate?.longitude ?: 0.0)
    )
  }

  fun takeSnapshotResult(requestId: Int, width: Int, height: Int, format: String, quality: Double, result: String) {
    adapter?.takeSnapshot(width, height, format, quality, result) { uri ->
      dispatchCommandResult(requestId, JSONObject().put("uri", uri))
    }
  }

  fun getMarkersFramesResult(requestId: Int, onlyVisible: Boolean) {
    val density = resources.displayMetrics.density
    val viewWidth = width
    val viewHeight = height
    val out = JSONObject()
    features.forEach { child ->
      if (child !is MarkerView) return@forEach
      val identifier = child.identifier ?: return@forEach
      val handle = child.cnHandle ?: return@forEach
      val screen = adapter?.markerScreenPoint(handle) ?: return@forEach
      if (onlyVisible && (screen.x < 0 || screen.y < 0 || screen.x > viewWidth || screen.y > viewHeight)) {
        return@forEach
      }
      val px = screen.x / density
      val py = screen.y / density
      out.put(
        identifier,
        JSONObject()
          .put("point", JSONObject().put("x", px).put("y", py))
          .put("frame", JSONObject().put("x", px).put("y", py).put("width", 0).put("height", 0))
      )
    }
    dispatchCommandResult(requestId, out)
  }

  // Appearance / config (forwarded to the adapter) -----------------------------

  fun setMapType(value: String?) { adapter?.setMapType(value) }
  fun setUserInterfaceStyle(value: String?) { adapter?.setUserInterfaceStyle(value) }
  fun setMinZoomLevel(value: Double) { adapter?.setMinZoomLevel(value) }
  fun setMaxZoomLevel(value: Double) { adapter?.setMaxZoomLevel(value) }
  fun setZoomEnabled(value: Boolean) { adapter?.setZoomEnabled(value) }
  fun setZoomControlEnabled(value: Boolean) { adapter?.setZoomControlEnabled(value) }
  fun setScrollEnabled(value: Boolean) { adapter?.setScrollEnabled(value) }
  fun setRotateEnabled(value: Boolean) { adapter?.setRotateEnabled(value) }
  fun setPitchEnabled(value: Boolean) { adapter?.setPitchEnabled(value) }
  fun setShowsUserLocation(value: Boolean) { adapter?.setShowsUserLocation(value) }
  fun setShowsMyLocationButton(value: Boolean) { adapter?.setShowsMyLocationButton(value) }
  fun setShowsCompass(value: Boolean) { adapter?.setShowsCompass(value) }
  fun setShowsScale(value: Boolean) { adapter?.setShowsScale(value) }
  fun setShowsTraffic(value: Boolean) { adapter?.setShowsTraffic(value) }
  fun setShowsBuildings(value: Boolean) { adapter?.setShowsBuildings(value) }
  fun setShowsIndoors(value: Boolean) { adapter?.setShowsIndoors(value) }
  fun setShowsIndoorLevelPicker(value: Boolean) { adapter?.setShowsIndoorLevelPicker(value) }
  fun setShowsPointsOfInterest(value: Boolean) { adapter?.setShowsPointsOfInterest(value) }

  // Child host-component management (called from the ViewGroupManager) ----------

  fun addFeature(child: View, index: Int) {
    val childId = nextChildId()
    when (child) {
      is MarkerView -> {
        child.cnChildId = childId
        child.mapHost = this
        child.cnHandle = adapter?.addMarker(child.markerModel(), childId)
      }
      is CnOverlayFeature -> {
        child.cnChildId = childId
        child.mapHost = this
        child.cnHandle = adapter?.addOverlay(child.overlayModel(), childId)
      }
      else -> {
        if (BuildConfig.DEBUG) {
          Log.w("RNMaps", "MapView.addFeature ignored unsupported child ${child.javaClass.simpleName}")
        }
        return
      }
    }
    childrenById[childId] = child
    features.add(index.coerceIn(0, features.size), child)
  }

  fun removeFeatureAt(index: Int) {
    if (index < 0 || index >= features.size) return
    val child = features.removeAt(index)
    detachFeature(child)
  }

  private fun detachFeature(child: View) {
    when (child) {
      is MarkerView -> child.cnHandle?.let { adapter?.removeMarker(it) }
      is CnOverlayFeature -> child.cnHandle?.let { adapter?.removeOverlay(it) }
    }
    (child as? CnMapFeature)?.let {
      it.cnChildId?.let { id -> childrenById.remove(id) }
      it.mapHost = null
      it.cnHandle = null
    }
  }

  fun getFeatureCount(): Int = features.size
  fun getFeatureAt(index: Int): View = features[index]

  // Lifecycle -----------------------------------------------------------------

  fun destroy() {
    if (didDestroy) return
    didDestroy = true
    reactContext.removeLifecycleEventListener(this)
    features.forEach { detachFeature(it) }
    features.clear()
    childrenById.clear()
    adapter?.onDestroy()
  }

  override fun onHostResume() { if (!didDestroy) adapter?.onResume() }
  override fun onHostPause() { if (!didDestroy) adapter?.onPause() }
  override fun onHostDestroy() { destroy() }

  override fun onSizeChanged(width: Int, height: Int, oldWidth: Int, oldHeight: Int) {
    super.onSizeChanged(width, height, oldWidth, oldHeight)
    adapter?.onSizeChanged()
  }

  // CnMapAdapterDelegate -------------------------------------------------------

  override fun onMapReady() {
    dispatchEvent(SimpleEvent(surfaceId(), id, "topMapReady"))
    dispatchEvent(SimpleEvent(surfaceId(), id, "topMapLoaded"))
  }

  override fun onMapPress(kind: CnPressKind, coordinate: CnLatLng, screenPoint: android.graphics.Point?) {
    val density = resources.displayMetrics.density
    val eventName = when (kind) {
      CnPressKind.PRESS -> "topPress"
      CnPressKind.LONG_PRESS -> "topLongPress"
      CnPressKind.DOUBLE_PRESS -> "topDoublePress"
      CnPressKind.PAN_DRAG -> "topPanDrag"
    }
    dispatchEvent(
      PressEvent(
        surfaceId(), id, eventName,
        coordinate.latitude, coordinate.longitude,
        (screenPoint?.x ?: 0) / density, (screenPoint?.y ?: 0) / density
      )
    )
  }

  override fun onRegionChange(complete: Boolean, isGesture: Boolean) {
    val region = adapter?.currentRegion() ?: return
    val eventName = if (complete) "topRegionChangeComplete" else "topRegionChange"
    dispatchEvent(RegionEvent(surfaceId(), id, eventName, region, isGesture))
  }

  override fun onPoiClick(poi: CnPoi) {
    val density = resources.displayMetrics.density
    val point = adapter?.pointForCoordinate(CnLatLng(poi.latitude, poi.longitude))
    dispatchEvent(
      PoiClickEvent(
        surfaceId(), id, poi.placeId, poi.name, poi.latitude, poi.longitude,
        (point?.x ?: 0) / density, (point?.y ?: 0) / density
      )
    )
  }

  override fun onUserLocationChange(location: CnUserLocation) {
    dispatchEvent(UserLocationChangeEvent(surfaceId(), id, location))
  }

  override fun onMarkerEvent(childId: String, event: CnMarkerEvent, coordinate: CnLatLng) {
    val marker = childrenById[childId] as? MarkerView ?: return
    marker.emitMarkerEvent(event, coordinate.latitude, coordinate.longitude)
  }

  override fun onOverlayPress(childId: String) {
    (childrenById[childId] as? PolylineView)?.emitPress()
  }

  override fun infoWindowViewFor(childId: String): View? =
    (childrenById[childId] as? MarkerView)?.getCalloutView()

  // Helpers / events -----------------------------------------------------------

  private fun edgeInsets(json: String?): CnEdgeInsets {
    val density = resources.displayMetrics.density
    val o = runCatching { JSONObject(json ?: "{}") }.getOrNull()
    fun edge(name: String): Int = ((o?.optDouble(name, 0.0) ?: 0.0) * density).toInt()
    return CnEdgeInsets(edge("top"), edge("right"), edge("bottom"), edge("left"))
  }

  private fun coordinatesFromJSON(json: String?): List<CnLatLng> {
    return runCatching {
      val arr = JSONArray(json ?: "[]")
      (0 until arr.length()).map {
        val o = arr.getJSONObject(it)
        CnLatLng(o.getDouble("latitude"), o.getDouble("longitude"))
      }
    }.getOrDefault(emptyList())
  }

  private fun surfaceId(): Int = UIManagerHelper.getSurfaceId(this)

  private fun dispatchEvent(event: Event<*>) {
    if (id == NO_ID) return
    UIManagerHelper.getEventDispatcher(reactContext)?.dispatchEvent(event)
  }

  private fun dispatchCommandResult(requestId: Int, data: JSONObject) {
    dispatchEvent(CommandResultEvent(surfaceId(), id, requestId, data.toString()))
  }

  private class RegionEvent(
    surfaceId: Int,
    viewId: Int,
    private val rnEventName: String,
    private val region: CnRegion,
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

  private class SimpleEvent(
    surfaceId: Int,
    viewId: Int,
    private val rnEventName: String
  ) : Event<SimpleEvent>(surfaceId, viewId) {
    override fun getEventName(): String = rnEventName
    override fun getEventData(): WritableMap = Arguments.createMap()
  }

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
        putMap("coordinate", Arguments.createMap().apply {
          putDouble("latitude", latitude)
          putDouble("longitude", longitude)
        })
        putMap("position", Arguments.createMap().apply {
          putDouble("x", x.toDouble())
          putDouble("y", y.toDouble())
        })
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
        putMap("coordinate", Arguments.createMap().apply {
          putDouble("latitude", latitude)
          putDouble("longitude", longitude)
        })
        putMap("position", Arguments.createMap().apply {
          putDouble("x", x.toDouble())
          putDouble("y", y.toDouble())
        })
      }
  }

  private class UserLocationChangeEvent(
    surfaceId: Int,
    viewId: Int,
    private val location: CnUserLocation
  ) : Event<UserLocationChangeEvent>(surfaceId, viewId) {
    override fun getEventName(): String = "topUserLocationChange"
    override fun canCoalesce(): Boolean = false
    override fun getEventData(): WritableMap =
      Arguments.createMap().apply {
        putMap("coordinate", Arguments.createMap().apply {
          putDouble("latitude", location.latitude)
          putDouble("longitude", location.longitude)
          putDouble("altitude", location.altitude)
          putDouble("accuracy", location.accuracy.toDouble())
          putDouble("speed", location.speed.toDouble())
          putDouble("heading", location.heading.toDouble())
          putBoolean("isFromMockProvider", location.isFromMockProvider)
        })
      }
  }
}
