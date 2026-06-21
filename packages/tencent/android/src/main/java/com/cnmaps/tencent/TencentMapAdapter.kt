package com.cnmaps.tencent

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Point
import android.util.Base64
import android.view.View
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
import com.cnmaps.adapter.CnPressKind
import com.cnmaps.adapter.CnRegion
import com.cnmaps.adapter.OverlayHandle
import com.tencent.tencentmap.mapsdk.maps.CameraUpdateFactory
import com.tencent.tencentmap.mapsdk.maps.MapView as TMapView
import com.tencent.tencentmap.mapsdk.maps.TencentMap
import com.tencent.tencentmap.mapsdk.maps.TencentMapInitializer
import com.tencent.tencentmap.mapsdk.maps.model.BitmapDescriptorFactory
import com.tencent.tencentmap.mapsdk.maps.model.CameraPosition
import com.tencent.tencentmap.mapsdk.maps.model.Circle
import com.tencent.tencentmap.mapsdk.maps.model.CircleOptions
import com.tencent.tencentmap.mapsdk.maps.model.GroundOverlay
import com.tencent.tencentmap.mapsdk.maps.model.GroundOverlayOptions
import com.tencent.tencentmap.mapsdk.maps.model.LatLng
import com.tencent.tencentmap.mapsdk.maps.model.LatLngBounds
import com.tencent.tencentmap.mapsdk.maps.model.Marker
import com.tencent.tencentmap.mapsdk.maps.model.MarkerOptions
import com.tencent.tencentmap.mapsdk.maps.model.Polygon
import com.tencent.tencentmap.mapsdk.maps.model.PolygonOptions
import com.tencent.tencentmap.mapsdk.maps.model.Polyline
import com.tencent.tencentmap.mapsdk.maps.model.PolylineOptions
import kotlin.math.abs

// Tencent (腾讯地图) implementation of CnMapAdapter. The Tencent vector SDK is
// Google-Maps-shaped. Coordinates from JS are already GCJ-02. APIs to re-check
// against the linked SDK version are tagged VERIFY.
class TencentMapAdapter(context: Context) : CnMapAdapter {
  private val mapView = TMapView(context)
  private val tencentMap: TencentMap = mapView.map

  override val providerName: String get() = "tencent"
  override val view: View get() = mapView
  override var delegate: CnMapAdapterDelegate? = null

  private var pendingInitialRegion: CnRegion? = null
  private var pendingInitialCamera: CnCamera? = null
  private var didApplyInitialRegion = false
  private var didApplyInitialCamera = false
  private var isGesture = false

  private val markerHandles = HashMap<String, OverlayHandle>()
  private val overlayHandles = ArrayList<OverlayHandle>()

  init {
    configureListeners()
  }

  override fun onResume() = mapView.onResume()
  override fun onPause() = mapView.onPause()
  override fun onDestroy() = mapView.onDestroy()
  override fun onSizeChanged() { applyPendingInitial() }

  // Configuration -------------------------------------------------------------

  override fun setMapType(value: String?) {
    tencentMap.mapType = when (value) {
      "satellite", "hybrid" -> TencentMap.MAP_TYPE_SATELLITE
      else -> TencentMap.MAP_TYPE_NORMAL
    }
  }
  override fun setUserInterfaceStyle(value: String?) { if (value == "dark") tencentMap.mapType = TencentMap.MAP_TYPE_DARK } // VERIFY constant
  override fun setMinZoomLevel(value: Double) { tencentMap.setMinZoomLevel(value.toInt()) } // VERIFY
  override fun setMaxZoomLevel(value: Double) { tencentMap.setMaxZoomLevel(value.toInt()) } // VERIFY
  override fun setZoomEnabled(value: Boolean) { tencentMap.uiSettings.setZoomGesturesEnabled(value) }
  override fun setZoomControlEnabled(value: Boolean) { tencentMap.uiSettings.setZoomControlsEnabled(value) }
  override fun setScrollEnabled(value: Boolean) { tencentMap.uiSettings.setScrollGesturesEnabled(value) }
  override fun setRotateEnabled(value: Boolean) { tencentMap.uiSettings.setRotateGesturesEnabled(value) }
  override fun setPitchEnabled(value: Boolean) { tencentMap.uiSettings.setTiltGesturesEnabled(value) }
  override fun setShowsUserLocation(value: Boolean) { tencentMap.isMyLocationEnabled = value }
  override fun setShowsMyLocationButton(value: Boolean) { tencentMap.uiSettings.setMyLocationButtonEnabled(value) }
  override fun setShowsCompass(value: Boolean) { tencentMap.uiSettings.setCompassEnabled(value) }
  override fun setShowsScale(value: Boolean) { tencentMap.uiSettings.setScaleViewEnabled(value) } // VERIFY
  override fun setShowsTraffic(value: Boolean) { tencentMap.isTrafficEnabled = value }
  override fun setShowsBuildings(value: Boolean) { tencentMap.setBuilding3dEffectEnable(value) } // VERIFY
  override fun setShowsIndoors(value: Boolean) { tencentMap.setIndoorEnabled(value) } // VERIFY
  override fun setShowsIndoorLevelPicker(value: Boolean) { /* no direct toggle */ }
  override fun setShowsPointsOfInterest(value: Boolean) { /* VERIFY: Tencent POI toggle */ }

  // Viewport ------------------------------------------------------------------

  override fun setInitialRegion(region: CnRegion) {
    if (didApplyInitialRegion || didApplyInitialCamera) return
    pendingInitialRegion = region; applyPendingInitial()
  }
  override fun setRegion(region: CnRegion) = moveToRegion(region, false, 0)
  override fun setInitialCamera(camera: CnCamera) {
    if (didApplyInitialCamera) return
    pendingInitialCamera = camera; applyPendingInitial()
  }
  override fun setCamera(camera: CnCamera) = moveToCamera(camera, false, 0)
  override fun animateToRegion(region: CnRegion, duration: Int) = moveToRegion(region, true, duration)
  override fun applyCamera(camera: CnCamera, animated: Boolean, duration: Int) {
    val resolved = if (camera.latitude == 0.0 && camera.longitude == 0.0) {
      val t = tencentMap.cameraPosition.target
      camera.copy(latitude = t.latitude, longitude = t.longitude)
    } else camera
    moveToCamera(resolved, animated, duration)
  }

  override fun currentRegion(): CnRegion? {
    val bounds = runCatching { tencentMap.projection.visibleRegion.latLngBounds }.getOrNull() ?: return null
    val target = tencentMap.cameraPosition.target ?: return null
    return CnRegion(
      target.latitude, target.longitude,
      abs(bounds.northeast.latitude - bounds.southwest.latitude),
      abs(bounds.northeast.longitude - bounds.southwest.longitude)
    )
  }

  override fun currentCamera(): CnCamera {
    val p = tencentMap.cameraPosition
    return CnCamera(p.target.latitude, p.target.longitude, p.bearing.toDouble(), p.tilt.toDouble(), p.zoom.toDouble(), 0.0)
  }

  override fun mapBoundaries(): Pair<CnLatLng, CnLatLng>? {
    val b = runCatching { tencentMap.projection.visibleRegion.latLngBounds }.getOrNull() ?: return null
    return CnLatLng(b.northeast.latitude, b.northeast.longitude) to CnLatLng(b.southwest.latitude, b.southwest.longitude)
  }

  override fun fitToCoordinates(coordinates: List<CnLatLng>, edgePadding: CnEdgeInsets, animated: Boolean) {
    if (coordinates.isEmpty()) return
    val builder = LatLngBounds.Builder()
    coordinates.forEach { builder.include(LatLng(it.latitude, it.longitude)) }
    val update = CameraUpdateFactory.newLatLngBoundsRect(builder.build(), edgePadding.left, edgePadding.right, edgePadding.top, edgePadding.bottom) // VERIFY
    if (animated) tencentMap.animateCamera(update) else tencentMap.moveCamera(update)
  }

  override fun fitToMarkers(handles: List<OverlayHandle>, edgePadding: CnEdgeInsets, animated: Boolean) {
    val builder = LatLngBounds.Builder(); var any = false
    handles.forEach { (it.sdkObject as? Marker)?.let { m -> builder.include(m.position); any = true } }
    if (any) {
      val update = CameraUpdateFactory.newLatLngBounds(builder.build(), 0)
      if (animated) tencentMap.animateCamera(update) else tencentMap.moveCamera(update)
    }
  }

  override fun setMapBoundaries(ne: CnLatLng, sw: CnLatLng) {
    // VERIFY: Tencent restrict-region API; best-effort no-op if unavailable.
  }

  // Projection ----------------------------------------------------------------

  override fun pointForCoordinate(coordinate: CnLatLng): Point? =
    runCatching { tencentMap.projection.toScreenLocation(LatLng(coordinate.latitude, coordinate.longitude)) }.getOrNull()

  override fun coordinateForPoint(xPx: Int, yPx: Int): CnLatLng? =
    runCatching { tencentMap.projection.fromScreenLocation(Point(xPx, yPx)) }.getOrNull()?.let { CnLatLng(it.latitude, it.longitude) }

  // Snapshot ------------------------------------------------------------------

  override fun takeSnapshot(width: Int, height: Int, format: String, quality: Double, result: String, completion: (uri: String) -> Unit) {
    tencentMap.snapshot { bitmap ->
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
    val options = MarkerOptions(LatLng(model.latitude, model.longitude))
      .draggable(model.draggable)
      .alpha(model.opacity)
      .rotation(model.rotation)
      .zIndex(model.zIndex)
    descriptorFor(model)?.let { options.icon(it) }
    val marker = tencentMap.addMarker(options)
    marker.tag = childId
    handle.sdkObject = marker
    markerHandles[childId] = handle
    return handle
  }

  override fun updateMarker(handle: OverlayHandle, model: CnMarkerModel) {
    val marker = handle.sdkObject as? Marker ?: return
    marker.position = LatLng(model.latitude, model.longitude)
    marker.alpha = model.opacity
    marker.rotation = model.rotation
    marker.isDraggable = model.draggable
    descriptorFor(model)?.let { marker.setIcon(it) }
  }

  override fun removeMarker(handle: OverlayHandle) {
    (handle.sdkObject as? Marker)?.remove()
    markerHandles.remove(handle.childId)
  }

  override fun showCallout(handle: OverlayHandle) { (handle.sdkObject as? Marker)?.showInfoWindow() }
  override fun hideCallout(handle: OverlayHandle) { (handle.sdkObject as? Marker)?.hideInfoWindow() }
  override fun redrawCallout(handle: OverlayHandle) { (handle.sdkObject as? Marker)?.let { if (it.isInfoWindowShown) it.showInfoWindow() } }

  override fun animateMarker(handle: OverlayHandle, latitude: Double, longitude: Double, duration: Int) {
    val marker = handle.sdkObject as? Marker ?: return
    if (duration <= 0) { marker.position = LatLng(latitude, longitude); return }
    // VERIFY: Tencent Marker.setAnimation / MarkerTranslateAnimator for a tween.
    marker.position = LatLng(latitude, longitude)
  }

  override fun markerScreenPoint(handle: OverlayHandle): Point? {
    val m = handle.sdkObject as? Marker ?: return null
    return runCatching { tencentMap.projection.toScreenLocation(m.position) }.getOrNull()
  }

  override fun markerPosition(handle: OverlayHandle): CnLatLng? {
    val m = handle.sdkObject as? Marker ?: return null
    return CnLatLng(m.position.latitude, m.position.longitude)
  }

  private fun descriptorFor(model: CnMarkerModel) =
    model.customBitmap?.let { BitmapDescriptorFactory.fromBitmap(it) }
      ?: model.iconBitmap?.let { BitmapDescriptorFactory.fromBitmap(it) }
  // null → Tencent default marker icon.

  // Overlays ------------------------------------------------------------------

  override fun addOverlay(model: CnOverlayModel, childId: String): OverlayHandle {
    val handle = OverlayHandle(childId)
    handle.sdkObject = buildOverlay(model)
    overlayHandles.add(handle)
    return handle
  }

  override fun updateOverlay(handle: OverlayHandle, model: CnOverlayModel) {
    removeSdk(handle.sdkObject)
    handle.sdkObject = buildOverlay(model)
  }

  override fun removeOverlay(handle: OverlayHandle) {
    removeSdk(handle.sdkObject)
    overlayHandles.remove(handle)
  }

  private fun removeSdk(obj: Any?) {
    when (obj) {
      is Polyline -> obj.remove()
      is Polygon -> obj.remove()
      is Circle -> obj.remove()
      is GroundOverlay -> obj.remove()
    }
  }

  private fun buildOverlay(model: CnOverlayModel): Any? = when (model) {
    is CnPolylineModel -> if (model.coordinates.size < 2) null else tencentMap.addPolyline(
      PolylineOptions()
        .addAll(model.coordinates.map { LatLng(it.latitude, it.longitude) })
        .width(model.strokeWidth)
        .color(if (model.strokeColors.isNotEmpty()) model.strokeColors[0] else model.strokeColor)
        .zIndex(model.zIndex.toInt())
    )
    is CnPolygonModel -> if (model.coordinates.size < 3) null else tencentMap.addPolygon(
      PolygonOptions()
        .addAll(model.coordinates.map { LatLng(it.latitude, it.longitude) })
        .strokeColor(model.strokeColor)
        .fillColor(model.fillColor)
        .strokeWidth(model.strokeWidth)
        .zIndex(model.zIndex.toInt())
      // NOTE: holes via PolygonOptions.addHole(...) is available on some versions; TODO.
    )
    is CnCircleModel -> tencentMap.addCircle(
      CircleOptions()
        .center(LatLng(model.center.latitude, model.center.longitude))
        .radius(model.radius)
        .strokeColor(model.strokeColor)
        .fillColor(model.fillColor)
        .strokeWidth(model.strokeWidth)
        .zIndex(model.zIndex.toInt())
    )
    // GroundOverlay / Heatmap / tiles use Tencent-specific APIs that differ per SDK
    // version (e.g. GroundOverlayOptions has no positionFromBounds); TODO (see README).
    else -> null
  }

  // Listeners -----------------------------------------------------------------

  private fun configureListeners() {
    tencentMap.setOnMapClickListener { latLng ->
      latLng?.let { delegate?.onMapPress(CnPressKind.PRESS, CnLatLng(it.latitude, it.longitude), screenPoint(it)) }
    }
    tencentMap.setOnMapLongClickListener { latLng ->
      latLng?.let { delegate?.onMapPress(CnPressKind.LONG_PRESS, CnLatLng(it.latitude, it.longitude), screenPoint(it)) }
    }
    tencentMap.setOnMapLoadedCallback { delegate?.onMapReady() } // VERIFY callback
    tencentMap.setOnMapPoiClickListener { poi ->
      poi?.let { delegate?.onPoiClick(CnPoi(it.name, it.name, it.position.latitude, it.position.longitude)) } // VERIFY MapPoi fields
    }
    tencentMap.setOnCameraChangeListener(object : TencentMap.OnCameraChangeListener {
      override fun onCameraChange(position: CameraPosition?) { delegate?.onRegionChange(complete = false, isGesture = isGesture) }
      override fun onCameraChangeFinished(position: CameraPosition?) { delegate?.onRegionChange(complete = true, isGesture = isGesture) }
    })
    tencentMap.setOnMarkerClickListener { marker ->
      val childId = marker.tag as? String
      if (childId != null) {
        val coord = CnLatLng(marker.position.latitude, marker.position.longitude)
        delegate?.onMarkerEvent(childId, CnMarkerEvent.PRESS, coord)
        delegate?.onMarkerEvent(childId, CnMarkerEvent.SELECT, coord)
      }
      true
    }
    tencentMap.setOnMarkerDragListener(object : TencentMap.OnMarkerDragListener {
      override fun onMarkerDragStart(marker: Marker?) = deliverDrag(marker, CnMarkerEvent.DRAG_START)
      override fun onMarkerDrag(marker: Marker?) = deliverDrag(marker, CnMarkerEvent.DRAG)
      override fun onMarkerDragEnd(marker: Marker?) = deliverDrag(marker, CnMarkerEvent.DRAG_END)
    })
  }

  private fun deliverDrag(marker: Marker?, event: CnMarkerEvent) {
    val m = marker ?: return
    val childId = m.tag as? String ?: return
    delegate?.onMarkerEvent(childId, event, CnLatLng(m.position.latitude, m.position.longitude))
  }

  private fun screenPoint(latLng: LatLng): Point? =
    runCatching { tencentMap.projection.toScreenLocation(latLng) }.getOrNull()

  // Helpers -------------------------------------------------------------------

  private fun applyPendingInitial() {
    if (mapView.width <= 0 || mapView.height <= 0) return
    pendingInitialRegion?.let { pendingInitialRegion = null; didApplyInitialRegion = true; moveToRegion(it, false, 0) }
    pendingInitialCamera?.let { pendingInitialCamera = null; didApplyInitialCamera = true; moveToCamera(it, false, 0) }
  }

  private fun moveToRegion(region: CnRegion, animated: Boolean, duration: Int) {
    val bounds = LatLngBounds(
      LatLng(region.latitude - region.latitudeDelta / 2, region.longitude - region.longitudeDelta / 2),
      LatLng(region.latitude + region.latitudeDelta / 2, region.longitude + region.longitudeDelta / 2)
    )
    val update = CameraUpdateFactory.newLatLngBounds(bounds, 0)
    if (animated) tencentMap.animateCamera(update, duration.toLong(), null) else tencentMap.moveCamera(update)
  }

  private fun moveToCamera(camera: CnCamera, animated: Boolean, duration: Int) {
    val zoom = if (camera.zoom > 0) camera.zoom.toFloat() else tencentMap.cameraPosition.zoom
    val position = CameraPosition(LatLng(camera.latitude, camera.longitude), zoom, camera.pitch.toFloat(), camera.heading.toFloat())
    val update = CameraUpdateFactory.newCameraPosition(position)
    if (animated) tencentMap.animateCamera(update, duration.toLong(), null) else tencentMap.moveCamera(update)
  }
}

// Factory + privacy entry point registered with the core registry.
object TencentMapAdapterFactory : CnMapAdapterFactory {
  override val providerName: String = "tencent"

  override fun create(context: Context): CnMapAdapter = TencentMapAdapter(context)

  override fun applyPrivacyConsent(context: Context, agreed: Boolean, contains: Boolean, shown: Boolean) {
    // VERIFY: Tencent privacy entry point for your SDK version.
    TencentMapInitializer.setAgreePrivacy(agreed)
  }
}
