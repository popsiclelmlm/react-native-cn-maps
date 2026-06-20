package com.cnmaps.baidu

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Point
import android.os.Bundle
import android.util.Base64
import android.view.View
import com.baidu.mapapi.SDKInitializer
import com.baidu.mapapi.map.BaiduMap
import com.baidu.mapapi.map.BitmapDescriptorFactory
import com.baidu.mapapi.map.Circle
import com.baidu.mapapi.map.CircleOptions
import com.baidu.mapapi.map.GroundOverlay
import com.baidu.mapapi.map.GroundOverlayOptions
import com.baidu.mapapi.map.MapPoi
import com.baidu.mapapi.map.MapStatus
import com.baidu.mapapi.map.MapStatusUpdateFactory
import com.baidu.mapapi.map.MapView as BMapView
import com.baidu.mapapi.map.Marker
import com.baidu.mapapi.map.MarkerOptions
import com.baidu.mapapi.map.Overlay
import com.baidu.mapapi.map.Polygon
import com.baidu.mapapi.map.PolygonOptions
import com.baidu.mapapi.map.Polyline
import com.baidu.mapapi.map.PolylineOptions
import com.baidu.mapapi.map.Stroke
import com.baidu.mapapi.model.LatLng
import com.baidu.mapapi.model.LatLngBounds
import com.cnmaps.adapter.CnCamera
import com.cnmaps.adapter.CnCircleModel
import com.cnmaps.adapter.CnEdgeInsets
import com.cnmaps.adapter.CnGroundOverlayModel
import com.cnmaps.adapter.CnLatLng
import com.cnmaps.adapter.CnMapAdapter
import com.cnmaps.adapter.CnMapAdapterDelegate
import com.cnmaps.adapter.CnMapAdapterFactory
import com.cnmaps.adapter.CnMarkerEvent
import com.cnmaps.adapter.CnMarkerModel
import com.cnmaps.adapter.CnOverlayModel
import com.cnmaps.adapter.CnPoi
import com.cnmaps.adapter.CnPolygonModel
import com.cnmaps.adapter.CnPolylineModel
import com.cnmaps.adapter.CnRegion
import com.cnmaps.adapter.OverlayHandle
import kotlin.math.abs

// Baidu (百度地图) implementation of CnMapAdapter. Coordinates from JS are already
// BD-09. APIs to re-check against the linked BaiduMapSDK version are tagged VERIFY.
class BaiduMapAdapter(context: Context) : CnMapAdapter {
  private val mapView = BMapView(context)
  private val baiduMap: BaiduMap = mapView.map

  override val providerName: String get() = "baidu"
  override val view: View get() = mapView
  override var delegate: CnMapAdapterDelegate? = null

  private var pendingInitialRegion: CnRegion? = null
  private var pendingInitialCamera: CnCamera? = null
  private var didApplyInitialRegion = false
  private var didApplyInitialCamera = false
  private var mapTypeProp: String? = null

  private val markerHandles = HashMap<String, OverlayHandle>() // childId → handle
  private val overlayHandles = ArrayList<OverlayHandle>()
  private var childIdSeq = 0

  init {
    configureListeners()
  }

  override fun onResume() = mapView.onResume()
  override fun onPause() = mapView.onPause()
  override fun onDestroy() = mapView.onDestroy()
  override fun onSizeChanged() { applyPendingInitial() }

  // Configuration -------------------------------------------------------------

  override fun setMapType(value: String?) {
    mapTypeProp = value
    baiduMap.mapType = when (value) {
      "satellite", "hybrid" -> BaiduMap.MAP_TYPE_SATELLITE
      else -> BaiduMap.MAP_TYPE_NORMAL
    }
  }
  override fun setUserInterfaceStyle(value: String?) { /* Baidu night needs a custom style file */ }
  override fun setMinZoomLevel(value: Double) { baiduMap.setMaxAndMinZoomLevel(baiduMap.maxZoomLevel, value.toFloat()) } // VERIFY
  override fun setMaxZoomLevel(value: Double) { baiduMap.setMaxAndMinZoomLevel(value.toFloat(), baiduMap.minZoomLevel) } // VERIFY
  override fun setZoomEnabled(value: Boolean) { baiduMap.uiSettings.isZoomGesturesEnabled = value }
  override fun setZoomControlEnabled(value: Boolean) { mapView.showZoomControls(value) }
  override fun setScrollEnabled(value: Boolean) { baiduMap.uiSettings.isScrollGesturesEnabled = value }
  override fun setRotateEnabled(value: Boolean) { baiduMap.uiSettings.isRotateGesturesEnabled = value }
  override fun setPitchEnabled(value: Boolean) { baiduMap.uiSettings.isOverlookingGesturesEnabled = value }
  override fun setShowsUserLocation(value: Boolean) { baiduMap.isMyLocationEnabled = value }
  override fun setShowsMyLocationButton(value: Boolean) { /* no direct Baidu toggle */ }
  override fun setShowsCompass(value: Boolean) { baiduMap.uiSettings.isCompassEnabled = value } // VERIFY
  override fun setShowsScale(value: Boolean) { mapView.showScaleControl(value) }
  override fun setShowsTraffic(value: Boolean) { baiduMap.isTrafficEnabled = value }
  override fun setShowsBuildings(value: Boolean) { baiduMap.isBuildingsEnabled = value }
  override fun setShowsIndoors(value: Boolean) { baiduMap.setIndoorEnable(value) } // VERIFY
  override fun setShowsIndoorLevelPicker(value: Boolean) { /* no direct toggle */ }
  override fun setShowsPointsOfInterest(value: Boolean) { baiduMap.showMapPoi(value) } // VERIFY

  // Viewport ------------------------------------------------------------------

  override fun setInitialRegion(region: CnRegion) {
    if (didApplyInitialRegion || didApplyInitialCamera) return
    pendingInitialRegion = region
    applyPendingInitial()
  }
  override fun setRegion(region: CnRegion) = moveToRegion(region, animated = false, duration = 0)
  override fun setInitialCamera(camera: CnCamera) {
    if (didApplyInitialCamera) return
    pendingInitialCamera = camera
    applyPendingInitial()
  }
  override fun setCamera(camera: CnCamera) = moveToCamera(camera, animated = false, duration = 0)
  override fun animateToRegion(region: CnRegion, duration: Int) = moveToRegion(region, true, duration)
  override fun applyCamera(camera: CnCamera, animated: Boolean, duration: Int) {
    val resolved = if (camera.latitude == 0.0 && camera.longitude == 0.0) {
      val t = baiduMap.mapStatus.target
      camera.copy(latitude = t.latitude, longitude = t.longitude)
    } else camera
    moveToCamera(resolved, animated, duration)
  }

  override fun currentRegion(): CnRegion? {
    val bounds = baiduMap.mapStatus?.bound ?: return null
    val target = baiduMap.mapStatus?.target ?: return null
    return CnRegion(
      target.latitude, target.longitude,
      abs(bounds.northeast.latitude - bounds.southwest.latitude),
      abs(bounds.northeast.longitude - bounds.southwest.longitude)
    )
  }

  override fun currentCamera(): CnCamera {
    val s = baiduMap.mapStatus
    return CnCamera(s.target.latitude, s.target.longitude, s.rotate.toDouble(), -s.overlook.toDouble(), s.zoom.toDouble(), 0.0)
  }

  override fun mapBoundaries(): Pair<CnLatLng, CnLatLng>? {
    val bounds = baiduMap.mapStatus?.bound ?: return null
    return CnLatLng(bounds.northeast.latitude, bounds.northeast.longitude) to
      CnLatLng(bounds.southwest.latitude, bounds.southwest.longitude)
  }

  override fun fitToCoordinates(coordinates: List<CnLatLng>, edgePadding: CnEdgeInsets, animated: Boolean) {
    if (coordinates.isEmpty()) return
    val builder = LatLngBounds.Builder()
    coordinates.forEach { builder.include(LatLng(it.latitude, it.longitude)) }
    val update = MapStatusUpdateFactory.newLatLngBounds(builder.build()) // VERIFY: padded variant
    if (animated) baiduMap.animateMapStatus(update) else baiduMap.setMapStatus(update)
  }

  override fun fitToMarkers(handles: List<OverlayHandle>, edgePadding: CnEdgeInsets, animated: Boolean) {
    val builder = LatLngBounds.Builder()
    var any = false
    handles.forEach { (it.sdkObject as? Marker)?.let { m -> builder.include(m.position); any = true } }
    if (any) {
      val update = MapStatusUpdateFactory.newLatLngBounds(builder.build())
      if (animated) baiduMap.animateMapStatus(update) else baiduMap.setMapStatus(update)
    }
  }

  override fun setMapBoundaries(ne: CnLatLng, sw: CnLatLng) {
    val bounds = LatLngBounds.Builder()
      .include(LatLng(ne.latitude, ne.longitude))
      .include(LatLng(sw.latitude, sw.longitude)).build()
    baiduMap.setMapStatusLimits(bounds) // VERIFY
  }

  // Projection ----------------------------------------------------------------

  override fun pointForCoordinate(coordinate: CnLatLng): Point? =
    runCatching { baiduMap.projection.toScreenLocation(LatLng(coordinate.latitude, coordinate.longitude)) }.getOrNull()

  override fun coordinateForPoint(xPx: Int, yPx: Int): CnLatLng? =
    runCatching { baiduMap.projection.fromScreenLocation(Point(xPx, yPx)) }
      .getOrNull()?.let { CnLatLng(it.latitude, it.longitude) }

  // Snapshot ------------------------------------------------------------------

  override fun takeSnapshot(width: Int, height: Int, format: String, quality: Double, result: String, completion: (uri: String) -> Unit) {
    baiduMap.snapshot { bitmap ->
      Thread { completion(encodeSnapshot(bitmap, width, height, format, quality, result)) }.start()
    }
  }

  private fun encodeSnapshot(bitmap: Bitmap?, width: Int, height: Int, format: String, quality: Double, result: String): String =
    runCatching {
      val source = bitmap ?: return@runCatching ""
      val scaled = if (width > 0 && height > 0) Bitmap.createScaledBitmap(source, width, height, true) else source
      val isJpg = format == "jpg" || format == "jpeg"
      val q = (quality.coerceIn(0.0, 1.0) * 100).toInt()
      val bytes = java.io.ByteArrayOutputStream().use { s ->
        scaled.compress(if (isJpg) Bitmap.CompressFormat.JPEG else Bitmap.CompressFormat.PNG, q, s); s.toByteArray()
      }
      if (result == "base64") Base64.encodeToString(bytes, Base64.NO_WRAP)
      else {
        val file = java.io.File(mapView.context.cacheDir, "map-snapshot-${System.identityHashCode(bytes)}.${if (isJpg) "jpg" else "png"}")
        java.io.FileOutputStream(file).use { it.write(bytes) }
        "file://${file.absolutePath}"
      }
    }.getOrDefault("")

  // Markers -------------------------------------------------------------------

  override fun addMarker(model: CnMarkerModel, childId: String): OverlayHandle {
    val handle = OverlayHandle(childId)
    val options = MarkerOptions()
      .position(LatLng(model.latitude, model.longitude))
      .draggable(model.draggable)
      .alpha(model.opacity)
      .rotate(model.rotationDegrees)
      .zIndex(model.zIndex.toInt())
      .icon(descriptorFor(model))
    val marker = baiduMap.addOverlay(options) as Marker
    marker.extraInfo = Bundle().apply { putString(CHILD_ID, childId) }
    handle.sdkObject = marker
    markerHandles[childId] = handle
    return handle
  }

  override fun updateMarker(handle: OverlayHandle, model: CnMarkerModel) {
    val marker = handle.sdkObject as? Marker ?: return
    marker.position = LatLng(model.latitude, model.longitude)
    marker.alpha = model.opacity
    marker.rotate = model.rotationDegrees
    marker.isDraggable = model.draggable
    marker.icon = descriptorFor(model)
  }

  override fun removeMarker(handle: OverlayHandle) {
    (handle.sdkObject as? Marker)?.remove()
    handle.childId.let { markerHandles.remove(it) }
  }

  override fun showCallout(handle: OverlayHandle) { /* Baidu InfoWindow is shown via baiduMap.showInfoWindow; custom callout TODO */ }
  override fun hideCallout(handle: OverlayHandle) { baiduMap.hideInfoWindow() }
  override fun redrawCallout(handle: OverlayHandle) { /* no-op until custom InfoWindow wired */ }

  override fun animateMarker(handle: OverlayHandle, latitude: Double, longitude: Double, duration: Int) {
    // Baidu has no built-in marker tween; set position (parity with 0-duration). VERIFY: Marker animation API.
    (handle.sdkObject as? Marker)?.position = LatLng(latitude, longitude)
  }

  override fun markerScreenPoint(handle: OverlayHandle): Point? {
    val m = handle.sdkObject as? Marker ?: return null
    return runCatching { baiduMap.projection.toScreenLocation(m.position) }.getOrNull()
  }

  override fun markerPosition(handle: OverlayHandle): CnLatLng? {
    val m = handle.sdkObject as? Marker ?: return null
    return CnLatLng(m.position.latitude, m.position.longitude)
  }

  private fun descriptorFor(model: CnMarkerModel) =
    model.customBitmap?.let { BitmapDescriptorFactory.fromBitmap(it) }
      ?: model.iconBitmap?.let { BitmapDescriptorFactory.fromBitmap(it) }
      ?: BitmapDescriptorFactory.fromResource(com.baidu.mapapi.map.R.drawable.icon_marka) // VERIFY default marker

  // Overlays ------------------------------------------------------------------

  override fun addOverlay(model: CnOverlayModel, childId: String): OverlayHandle {
    val handle = OverlayHandle(childId)
    handle.sdkObject = buildOverlay(model)
    overlayHandles.add(handle)
    return handle
  }

  override fun updateOverlay(handle: OverlayHandle, model: CnOverlayModel) {
    (handle.sdkObject as? Overlay)?.remove()
    handle.sdkObject = buildOverlay(model)
  }

  override fun removeOverlay(handle: OverlayHandle) {
    (handle.sdkObject as? Overlay)?.remove()
    overlayHandles.remove(handle)
  }

  private fun buildOverlay(model: CnOverlayModel): Overlay? = when (model) {
    is CnPolylineModel -> {
      if (model.coordinates.size < 2) null else baiduMap.addOverlay(
        PolylineOptions()
          .points(model.coordinates.map { LatLng(it.latitude, it.longitude) })
          .width(model.strokeWidth.toInt())
          .color(if (model.strokeColors.isNotEmpty()) model.strokeColors[0] else model.strokeColor)
          .dottedLine(model.dashed)
          .zIndex(model.zIndex.toInt())
      )
    }
    is CnPolygonModel -> {
      if (model.coordinates.size < 3) null else baiduMap.addOverlay(
        PolygonOptions()
          .points(model.coordinates.map { LatLng(it.latitude, it.longitude) })
          .stroke(Stroke(model.strokeWidth.toInt(), model.strokeColor))
          .fillColor(model.fillColor)
          .zIndex(model.zIndex.toInt())
      )
      // NOTE: Baidu PolygonOptions has no interior-holes API; `holes` is dropped.
    }
    is CnCircleModel -> baiduMap.addOverlay(
      CircleOptions()
        .center(LatLng(model.center.latitude, model.center.longitude))
        .radius(model.radius.toInt())
        .stroke(Stroke(model.strokeWidth.toInt(), model.strokeColor))
        .fillColor(model.fillColor)
        .zIndex(model.zIndex.toInt())
    )
    is CnGroundOverlayModel -> {
      val sw = model.southWest; val ne = model.northEast; val bmp = model.bitmap
      if (sw == null || ne == null || bmp == null) null else baiduMap.addOverlay(
        GroundOverlayOptions()
          .positionFromBounds(LatLngBounds.Builder().include(LatLng(sw.latitude, sw.longitude)).include(LatLng(ne.latitude, ne.longitude)).build())
          .image(BitmapDescriptorFactory.fromBitmap(bmp))
          .transparency((1f - model.opacity).coerceIn(0f, 1f))
          .zIndex(model.zIndex.toInt())
      )
    }
    // Heatmap uses baiduMap.addHeatMap(...) and tiles use addTileLayer(...); both are
    // not `Overlay` objects, so they are TODO for Baidu (see package README).
    else -> null
  }

  // Listeners -----------------------------------------------------------------

  private fun configureListeners() {
    baiduMap.setOnMapClickListener(object : BaiduMap.OnMapClickListener {
      override fun onMapClick(latLng: LatLng?) {
        latLng?.let { delegate?.onMapPress(com.cnmaps.adapter.CnPressKind.PRESS, CnLatLng(it.latitude, it.longitude), screenPoint(it)) }
      }
      override fun onMapPoiClick(poi: MapPoi?) {
        poi?.position?.let { delegate?.onPoiClick(CnPoi(poi.uid, poi.name, it.latitude, it.longitude)) }
      }
    })

    baiduMap.setOnMapLongClickListener { latLng ->
      latLng?.let { delegate?.onMapPress(com.cnmaps.adapter.CnPressKind.LONG_PRESS, CnLatLng(it.latitude, it.longitude), screenPoint(it)) }
    }

    baiduMap.setOnMapLoadedCallback { delegate?.onMapReady() }

    baiduMap.setOnMapStatusChangeListener(object : BaiduMap.OnMapStatusChangeListener {
      override fun onMapStatusChangeStart(status: MapStatus?) {}
      override fun onMapStatusChangeStart(status: MapStatus?, reason: Int) {}
      override fun onMapStatusChange(status: MapStatus?) { delegate?.onRegionChange(complete = false, isGesture = true) }
      override fun onMapStatusChangeFinish(status: MapStatus?) { delegate?.onRegionChange(complete = true, isGesture = true) }
    })

    baiduMap.setOnMarkerClickListener { marker ->
      val childId = marker.extraInfo?.getString(CHILD_ID)
      if (childId != null) {
        val coord = CnLatLng(marker.position.latitude, marker.position.longitude)
        delegate?.onMarkerEvent(childId, CnMarkerEvent.PRESS, coord)
        delegate?.onMarkerEvent(childId, CnMarkerEvent.SELECT, coord)
      }
      true
    }

    baiduMap.setOnMarkerDragListener(object : BaiduMap.OnMarkerDragListener {
      override fun onMarkerDragStart(marker: Marker?) = deliverDrag(marker, CnMarkerEvent.DRAG_START)
      override fun onMarkerDrag(marker: Marker?) = deliverDrag(marker, CnMarkerEvent.DRAG)
      override fun onMarkerDragEnd(marker: Marker?) = deliverDrag(marker, CnMarkerEvent.DRAG_END)
    })
  }

  private fun deliverDrag(marker: Marker?, event: CnMarkerEvent) {
    val m = marker ?: return
    val childId = m.extraInfo?.getString(CHILD_ID) ?: return
    delegate?.onMarkerEvent(childId, event, CnLatLng(m.position.latitude, m.position.longitude))
  }

  private fun screenPoint(latLng: LatLng): Point? =
    runCatching { baiduMap.projection.toScreenLocation(latLng) }.getOrNull()

  // Helpers -------------------------------------------------------------------

  private fun applyPendingInitial() {
    if (mapView.width <= 0 || mapView.height <= 0) return
    pendingInitialRegion?.let { pendingInitialRegion = null; didApplyInitialRegion = true; moveToRegion(it, false, 0) }
    pendingInitialCamera?.let { pendingInitialCamera = null; didApplyInitialCamera = true; moveToCamera(it, false, 0) }
  }

  private fun moveToRegion(region: CnRegion, animated: Boolean, duration: Int) {
    val bounds = LatLngBounds.Builder()
      .include(LatLng(region.latitude - region.latitudeDelta / 2, region.longitude - region.longitudeDelta / 2))
      .include(LatLng(region.latitude + region.latitudeDelta / 2, region.longitude + region.longitudeDelta / 2))
      .build()
    val update = MapStatusUpdateFactory.newLatLngBounds(bounds)
    if (animated) baiduMap.animateMapStatus(update, duration.coerceAtLeast(0)) else baiduMap.setMapStatus(update)
  }

  private fun moveToCamera(camera: CnCamera, animated: Boolean, duration: Int) {
    val builder = MapStatus.Builder()
      .target(LatLng(camera.latitude, camera.longitude))
      .rotate(camera.heading.toFloat())
      .overlook((-camera.pitch).toFloat())
    if (camera.zoom > 0) builder.zoom(camera.zoom.toFloat())
    val update = MapStatusUpdateFactory.newMapStatus(builder.build())
    if (animated) baiduMap.animateMapStatus(update, duration.coerceAtLeast(0)) else baiduMap.setMapStatus(update)
  }

  private companion object {
    private const val CHILD_ID = "cn_child_id"
  }
}

// Factory + privacy entry point registered with the core registry.
object BaiduMapAdapterFactory : CnMapAdapterFactory {
  override val providerName: String = "baidu"

  override fun create(context: Context): CnMapAdapter = BaiduMapAdapter(context)

  override fun applyPrivacyConsent(context: Context, agreed: Boolean, contains: Boolean, shown: Boolean) {
    // Baidu must agree to privacy before SDK init, then initialize once.
    SDKInitializer.setAgreePrivacy(context.applicationContext, agreed)
    runCatching { SDKInitializer.initialize(context.applicationContext) }
  }
}
