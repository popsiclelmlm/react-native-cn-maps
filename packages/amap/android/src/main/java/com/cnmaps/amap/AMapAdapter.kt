package com.cnmaps.amap

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Point
import android.util.Base64
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import com.amap.api.maps.AMap
import com.amap.api.maps.CameraUpdate
import com.amap.api.maps.CameraUpdateFactory
import com.amap.api.maps.MapView as AMapView
import com.amap.api.maps.MapsInitializer
import com.amap.api.maps.model.BitmapDescriptor
import com.amap.api.maps.model.BitmapDescriptorFactory
import com.amap.api.maps.model.CameraPosition
import com.amap.api.maps.model.Circle
import com.amap.api.maps.model.CircleOptions
import com.amap.api.maps.model.Gradient
import com.amap.api.maps.model.GroundOverlay
import com.amap.api.maps.model.GroundOverlayOptions
import com.amap.api.maps.model.HeatmapTileProvider
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.LatLngBounds
import com.amap.api.maps.model.Marker
import com.amap.api.maps.model.MarkerOptions
import com.amap.api.maps.model.Poi
import com.amap.api.maps.model.Polygon
import com.amap.api.maps.model.PolygonHoleOptions
import com.amap.api.maps.model.PolygonOptions
import com.amap.api.maps.model.Polyline
import com.amap.api.maps.model.PolylineOptions
import com.amap.api.maps.model.Tile
import com.amap.api.maps.model.TileOverlay
import com.amap.api.maps.model.TileOverlayOptions
import com.amap.api.maps.model.TileProvider
import com.amap.api.maps.model.UrlTileProvider
import com.amap.api.maps.model.WeightedLatLng
import com.cnmaps.adapter.CnCamera
import com.cnmaps.adapter.CnEdgeInsets
import com.cnmaps.adapter.CnGroundOverlayModel
import com.cnmaps.adapter.CnLatLng
import com.cnmaps.adapter.CnLocalTileModel
import com.cnmaps.adapter.CnMapAdapter
import com.cnmaps.adapter.CnMapAdapterDelegate
import com.cnmaps.adapter.CnMapAdapterFactory
import com.cnmaps.adapter.CnMarkerEvent
import com.cnmaps.adapter.CnMarkerModel
import com.cnmaps.adapter.CnCircleModel
import com.cnmaps.adapter.CnHeatmapModel
import com.cnmaps.adapter.CnOverlayModel
import com.cnmaps.adapter.CnPoi
import com.cnmaps.adapter.CnPolygonModel
import com.cnmaps.adapter.CnPolylineModel
import com.cnmaps.adapter.CnPressKind
import com.cnmaps.adapter.CnRegion
import com.cnmaps.adapter.CnUrlTileModel
import com.cnmaps.adapter.CnUserLocation
import com.cnmaps.adapter.OverlayHandle
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.MalformedURLException
import java.net.URL
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min

// AMap (高德) implementation of CnMapAdapter. Owns the AMap MapView + its
// listeners, and is the single place in the Android layer that references the AMap
// SDK in the map layer.
class AMapAdapter(context: Context) : CnMapAdapter {
  private val mapView = AMapView(context)
  private val aMap: AMap = mapView.map
  private val gestureDetector = GestureDetector(context, GestureListener())

  override val view: View get() = mapView
  override var delegate: CnMapAdapterDelegate? = null

  private var pendingInitialRegion: CnRegion? = null
  private var pendingInitialCamera: CnCamera? = null
  private var didApplyInitialRegion = false
  private var didApplyInitialCamera = false
  private var isGesture = false
  private var mapTypeProp: String? = null
  private var userInterfaceStyleProp: String? = null

  private val markerHandles = ArrayList<OverlayHandle>()
  private val markerModels = HashMap<OverlayHandle, CnMarkerModel>()
  private val markerAnimators = HashMap<OverlayHandle, ValueAnimator>()
  private val overlayHandles = ArrayList<OverlayHandle>()
  private val overlayModels = HashMap<OverlayHandle, CnOverlayModel>()

  init {
    mapView.onCreate(null)
    aMap.uiSettings.isZoomControlsEnabled = false
    configureListeners()
  }

  override fun onResume() = mapView.onResume()
  override fun onPause() = mapView.onPause()
  override fun onDestroy() = mapView.onDestroy()
  override fun onSizeChanged() = applyPendingInitialCamera()

  // Configuration -------------------------------------------------------------

  override fun setMapType(value: String?) {
    mapTypeProp = value
    applyMapType()
  }

  override fun setUserInterfaceStyle(value: String?) {
    userInterfaceStyleProp = value
    applyMapType()
  }

  private fun applyMapType() {
    aMap.mapType = when {
      mapTypeProp == "satellite" || mapTypeProp == "hybrid" -> AMap.MAP_TYPE_SATELLITE
      userInterfaceStyleProp == "dark" -> AMap.MAP_TYPE_NIGHT
      else -> AMap.MAP_TYPE_NORMAL
    }
  }

  override fun setMinZoomLevel(value: Double) { aMap.minZoomLevel = value.toFloat() }
  override fun setMaxZoomLevel(value: Double) { aMap.maxZoomLevel = value.toFloat() }
  override fun setZoomEnabled(value: Boolean) { aMap.uiSettings.isZoomGesturesEnabled = value }
  override fun setZoomControlEnabled(value: Boolean) { aMap.uiSettings.isZoomControlsEnabled = value }
  override fun setScrollEnabled(value: Boolean) { aMap.uiSettings.isScrollGesturesEnabled = value }
  override fun setRotateEnabled(value: Boolean) { aMap.uiSettings.isRotateGesturesEnabled = value }
  override fun setPitchEnabled(value: Boolean) { aMap.uiSettings.isTiltGesturesEnabled = value }
  override fun setShowsUserLocation(value: Boolean) { aMap.isMyLocationEnabled = value }
  override fun setShowsMyLocationButton(value: Boolean) { aMap.uiSettings.isMyLocationButtonEnabled = value }
  override fun setShowsCompass(value: Boolean) { aMap.uiSettings.isCompassEnabled = value }
  override fun setShowsScale(value: Boolean) { aMap.uiSettings.isScaleControlsEnabled = value }
  override fun setShowsTraffic(value: Boolean) { aMap.isTrafficEnabled = value }
  override fun setShowsBuildings(value: Boolean) { aMap.showBuildings(value) }
  override fun setShowsIndoors(value: Boolean) { aMap.showIndoorMap(value) }
  override fun setShowsIndoorLevelPicker(value: Boolean) { aMap.uiSettings.isIndoorSwitchEnabled = value }
  override fun setShowsPointsOfInterest(value: Boolean) { aMap.showMapText(value) }

  // Viewport ------------------------------------------------------------------

  override fun setInitialRegion(region: CnRegion) {
    if (didApplyInitialRegion || didApplyInitialCamera) return
    pendingInitialRegion = region
    applyPendingInitialCamera()
  }

  override fun setRegion(region: CnRegion) = moveToRegion(region, animated = false)

  override fun setInitialCamera(camera: CnCamera) {
    if (didApplyInitialCamera) return
    pendingInitialCamera = camera
    applyPendingInitialCamera()
  }

  override fun setCamera(camera: CnCamera) = moveToCamera(camera, animated = false)

  override fun animateToRegion(region: CnRegion, duration: Int) =
    moveToRegion(region, animated = true, duration = duration)

  override fun applyCamera(camera: CnCamera, animated: Boolean, duration: Int) {
    val resolved = if (camera.latitude == 0.0 && camera.longitude == 0.0) {
      val target = aMap.cameraPosition.target
      camera.copy(latitude = target.latitude, longitude = target.longitude)
    } else {
      camera
    }
    moveToCamera(resolved, animated, duration)
  }

  override fun currentRegion(): CnRegion? {
    val bounds = runCatching { aMap.projection.visibleRegion.latLngBounds }.getOrNull() ?: return null
    val target = aMap.cameraPosition.target ?: return null
    return CnRegion(
      latitude = target.latitude,
      longitude = target.longitude,
      latitudeDelta = abs(bounds.northeast.latitude - bounds.southwest.latitude),
      longitudeDelta = abs(bounds.northeast.longitude - bounds.southwest.longitude)
    )
  }

  override fun currentCamera(): CnCamera {
    val position = aMap.cameraPosition
    return CnCamera(
      latitude = position.target.latitude,
      longitude = position.target.longitude,
      heading = position.bearing.toDouble(),
      pitch = position.tilt.toDouble(),
      zoom = position.zoom.toDouble(),
      altitude = 0.0
    )
  }

  override fun mapBoundaries(): Pair<CnLatLng, CnLatLng>? {
    val bounds = runCatching { aMap.projection.visibleRegion.latLngBounds }.getOrNull() ?: return null
    return CnLatLng(bounds.northeast.latitude, bounds.northeast.longitude) to
      CnLatLng(bounds.southwest.latitude, bounds.southwest.longitude)
  }

  override fun fitToCoordinates(coordinates: List<CnLatLng>, edgePadding: CnEdgeInsets, animated: Boolean) {
    if (coordinates.isEmpty()) return
    val builder = LatLngBounds.Builder()
    coordinates.forEach { builder.include(LatLng(it.latitude, it.longitude)) }
    applyBounds(builder.build(), edgePadding, animated)
  }

  override fun fitToMarkers(handles: List<OverlayHandle>, edgePadding: CnEdgeInsets, animated: Boolean) {
    val builder = LatLngBounds.Builder()
    var any = false
    handles.forEach { handle ->
      (handle.sdkObject as? Marker)?.let { builder.include(it.position); any = true }
    }
    if (any) applyBounds(builder.build(), edgePadding, animated)
  }

  override fun setMapBoundaries(ne: CnLatLng, sw: CnLatLng) {
    runCatching {
      aMap.setMapStatusLimits(
        LatLngBounds(LatLng(sw.latitude, sw.longitude), LatLng(ne.latitude, ne.longitude))
      )
    }
  }

  // Projection ----------------------------------------------------------------

  override fun pointForCoordinate(coordinate: CnLatLng): Point? =
    runCatching { aMap.projection.toScreenLocation(LatLng(coordinate.latitude, coordinate.longitude)) }.getOrNull()

  override fun coordinateForPoint(xPx: Int, yPx: Int): CnLatLng? =
    runCatching { aMap.projection.fromScreenLocation(Point(xPx, yPx)) }
      .getOrNull()?.let { CnLatLng(it.latitude, it.longitude) }

  // Snapshot ------------------------------------------------------------------

  override fun takeSnapshot(
    width: Int,
    height: Int,
    format: String,
    quality: Double,
    result: String,
    completion: (uri: String) -> Unit
  ) {
    aMap.getMapScreenShot(object : AMap.OnMapScreenShotListener {
      override fun onMapScreenShot(bitmap: Bitmap?) {
        // Offload scaling/compression/IO so a large snapshot can't jank/ANR the UI.
        Thread { completion(encodeSnapshot(bitmap, width, height, format, quality, result)) }.start()
      }

      override fun onMapScreenShot(bitmap: Bitmap?, status: Int) {
        // Unused: the no-status overload already delivers the result.
      }
    })
  }

  private fun encodeSnapshot(
    bitmap: Bitmap?,
    width: Int,
    height: Int,
    format: String,
    quality: Double,
    result: String
  ): String = runCatching {
    val source = bitmap ?: return@runCatching ""
    val scaled = if (width > 0 && height > 0) Bitmap.createScaledBitmap(source, width, height, true) else source
    val isJpg = format == "jpg" || format == "jpeg"
    val q = (quality.coerceIn(0.0, 1.0) * 100).toInt()
    val bytes = ByteArrayOutputStream().use { stream ->
      scaled.compress(if (isJpg) Bitmap.CompressFormat.JPEG else Bitmap.CompressFormat.PNG, q, stream)
      stream.toByteArray()
    }
    if (result == "base64") {
      Base64.encodeToString(bytes, Base64.NO_WRAP)
    } else {
      val ext = if (isJpg) "jpg" else "png"
      val file = File(mapView.context.cacheDir, "map-snapshot-${System.identityHashCode(bytes)}.$ext")
      FileOutputStream(file).use { it.write(bytes) }
      "file://${file.absolutePath}"
    }
  }.getOrDefault("")

  // Markers -------------------------------------------------------------------

  override fun addMarker(model: CnMarkerModel, childId: String): OverlayHandle {
    val handle = OverlayHandle(childId)
    val options = MarkerOptions()
      .position(LatLng(model.latitude, model.longitude))
      .draggable(model.draggable)
      .anchor(model.anchorU, model.anchorV)
      .alpha(model.opacity)
      .setFlat(model.flat)
      .rotateAngle(rnRotationToAMap(model.rotation))
      .zIndex(model.zIndex)
      .icon(descriptorFor(model))
    model.title?.let { options.title(it) }
    model.snippet?.let { options.snippet(it) }
    val marker = aMap.addMarker(options)
    marker.`object` = handle
    handle.sdkObject = marker
    markerHandles.add(handle)
    markerModels[handle] = model
    return handle
  }

  override fun updateMarker(handle: OverlayHandle, model: CnMarkerModel) {
    val marker = handle.sdkObject as? Marker ?: return
    val previous = markerModels[handle]
    marker.position = LatLng(model.latitude, model.longitude)
    marker.title = model.title ?: ""
    marker.snippet = model.snippet ?: ""
    marker.isDraggable = model.draggable
    marker.setAnchor(model.anchorU, model.anchorV)
    marker.alpha = model.opacity
    marker.isFlat = model.flat
    marker.rotateAngle = rnRotationToAMap(model.rotation)
    marker.zIndex = model.zIndex
    // Only rebuild the icon when an icon input actually changed (avoids flicker).
    if (previous == null ||
      previous.customBitmap !== model.customBitmap ||
      previous.iconBitmap !== model.iconBitmap ||
      previous.pinColor != model.pinColor
    ) {
      marker.setIcon(descriptorFor(model))
    }
    markerModels[handle] = model
  }

  override fun removeMarker(handle: OverlayHandle) {
    markerAnimators.remove(handle)?.cancel()
    (handle.sdkObject as? Marker)?.remove()
    markerHandles.remove(handle)
    markerModels.remove(handle)
  }

  override fun showCallout(handle: OverlayHandle) { (handle.sdkObject as? Marker)?.showInfoWindow() }
  override fun hideCallout(handle: OverlayHandle) { (handle.sdkObject as? Marker)?.hideInfoWindow() }
  override fun redrawCallout(handle: OverlayHandle) {
    (handle.sdkObject as? Marker)?.let { if (it.isInfoWindowShown) it.showInfoWindow() }
  }

  override fun animateMarker(handle: OverlayHandle, latitude: Double, longitude: Double, duration: Int) {
    val marker = handle.sdkObject as? Marker ?: return
    markerAnimators.remove(handle)?.cancel()
    val start = marker.position
    val end = LatLng(latitude, longitude)
    if (duration <= 0) {
      marker.position = end
      return
    }
    val animator = ValueAnimator.ofFloat(0f, 1f).apply {
      this.duration = duration.toLong()
      addUpdateListener { animation ->
        val t = animation.animatedValue as Float
        marker.position = LatLng(
          start.latitude + (end.latitude - start.latitude) * t,
          start.longitude + (end.longitude - start.longitude) * t
        )
      }
    }
    markerAnimators[handle] = animator
    animator.start()
  }

  override fun markerScreenPoint(handle: OverlayHandle): Point? {
    val marker = handle.sdkObject as? Marker ?: return null
    return runCatching { aMap.projection.toScreenLocation(marker.position) }.getOrNull()
  }

  override fun markerPosition(handle: OverlayHandle): CnLatLng? {
    val marker = handle.sdkObject as? Marker ?: return null
    return CnLatLng(marker.position.latitude, marker.position.longitude)
  }

  // Priority: rasterized custom React content > loaded image bitmap > hue-tinted
  // default pin > plain default marker.
  private fun descriptorFor(model: CnMarkerModel): BitmapDescriptor {
    model.customBitmap?.let { return BitmapDescriptorFactory.fromBitmap(it) }
    model.iconBitmap?.let { return BitmapDescriptorFactory.fromBitmap(it) }
    val hue = markerHue(model.pinColor)
    return if (hue != null) BitmapDescriptorFactory.defaultMarker(hue) else BitmapDescriptorFactory.defaultMarker()
  }

  // Overlays ------------------------------------------------------------------

  override fun addOverlay(model: CnOverlayModel, childId: String): OverlayHandle {
    val handle = OverlayHandle(childId)
    handle.sdkObject = buildOverlay(model)
    overlayHandles.add(handle)
    overlayModels[handle] = model
    return handle
  }

  override fun updateOverlay(handle: OverlayHandle, model: CnOverlayModel) {
    removeSdkOverlay(handle.sdkObject)
    handle.sdkObject = buildOverlay(model)
    overlayModels[handle] = model
  }

  override fun removeOverlay(handle: OverlayHandle) {
    removeSdkOverlay(handle.sdkObject)
    overlayHandles.remove(handle)
    overlayModels.remove(handle)
  }

  private fun removeSdkOverlay(sdkObject: Any?) {
    when (sdkObject) {
      is Polyline -> sdkObject.remove()
      is Polygon -> sdkObject.remove()
      is Circle -> sdkObject.remove()
      is TileOverlay -> sdkObject.remove()
      is GroundOverlay -> sdkObject.remove()
    }
  }

  private fun buildOverlay(model: CnOverlayModel): Any? = when (model) {
    is CnPolylineModel -> buildPolyline(model)
    is CnPolygonModel -> buildPolygon(model)
    is CnCircleModel -> buildCircle(model)
    is CnHeatmapModel -> buildHeatmap(model)
    is CnUrlTileModel -> buildUrlTile(model)
    is CnLocalTileModel -> buildLocalTile(model)
    is CnGroundOverlayModel -> buildGroundOverlay(model)
  }

  private fun buildPolyline(model: CnPolylineModel): Polyline {
    val options = PolylineOptions()
      .addAll(model.coordinates.map { LatLng(it.latitude, it.longitude) })
      .width(model.strokeWidth)
      .zIndex(model.zIndex)
      .geodesic(model.geodesic)
      .setDottedLine(model.dashed)
    when {
      model.strokeColors.size > 1 -> options.colorValues(ArrayList(model.strokeColors)).useGradient(true)
      model.strokeColors.size == 1 -> options.color(model.strokeColors[0])
      else -> options.color(model.strokeColor)
    }
    polylineLineCap(model.lineCap)?.let { options.lineCapType(it) }
    polylineLineJoin(model.lineJoin)?.let { options.lineJoinType(it) }
    return aMap.addPolyline(options)
  }

  private fun buildPolygon(model: CnPolygonModel): Polygon {
    val options = PolygonOptions()
      .addAll(model.coordinates.map { LatLng(it.latitude, it.longitude) })
      .strokeColor(model.strokeColor)
      .fillColor(model.fillColor)
      .strokeWidth(model.strokeWidth)
      .zIndex(model.zIndex)
    model.holes.forEach { ring ->
      options.addHoles(PolygonHoleOptions().addAll(ring.map { LatLng(it.latitude, it.longitude) }))
    }
    return aMap.addPolygon(options)
  }

  private fun buildCircle(model: CnCircleModel): Circle = aMap.addCircle(
    CircleOptions()
      .center(LatLng(model.center.latitude, model.center.longitude))
      .radius(model.radius)
      .strokeColor(model.strokeColor)
      .fillColor(model.fillColor)
      .strokeWidth(model.strokeWidth)
      .zIndex(model.zIndex)
  )

  private fun buildHeatmap(model: CnHeatmapModel): TileOverlay? {
    if (model.points.isEmpty()) return null
    val weighted = model.points.map { WeightedLatLng(LatLng(it.latitude, it.longitude), it.weight) }
    val builder = HeatmapTileProvider.Builder().weightedData(weighted).radius(model.radius)
    // Capture into locals: model.* are cross-module (core) properties and can't be
    // smart-cast to non-null in this (amap) module.
    val colors = model.gradientColors
    val starts = model.gradientStartPoints
    if (colors != null && starts != null && colors.isNotEmpty() && colors.size == starts.size) {
      builder.gradient(Gradient(colors, starts))
    }
    return aMap.addTileOverlay(TileOverlayOptions().tileProvider(builder.build()))
  }

  private fun buildUrlTile(model: CnUrlTileModel): TileOverlay? {
    val template = model.urlTemplate ?: return null
    val provider = object : UrlTileProvider(model.tileSize, model.tileSize) {
      override fun getTileUrl(x: Int, y: Int, zoom: Int): URL? {
        if (zoom < model.minimumZ || zoom > model.maximumZ) return null
        val url = if (model.wms) {
          wmsUrl(template, x, y, zoom, model.tileSize)
        } else {
          val yy = if (model.flipY) (1 shl zoom) - 1 - y else y
          template.replace("{x}", x.toString()).replace("{y}", yy.toString()).replace("{z}", zoom.toString())
        }
        return try { URL(url) } catch (e: MalformedURLException) { null }
      }
    }
    val options = TileOverlayOptions().tileProvider(provider).zIndex(model.zIndex)
    if (!model.diskCacheDir.isNullOrEmpty()) {
      options.diskCacheEnabled(true).diskCacheDir(model.diskCacheDir)
    }
    return aMap.addTileOverlay(options)
  }

  private fun buildLocalTile(model: CnLocalTileModel): TileOverlay? {
    val template = model.pathTemplate ?: return null
    val assets = if (model.useAssets) mapView.context.assets else null
    val provider = object : TileProvider {
      override fun getTile(x: Int, y: Int, zoom: Int): Tile {
        val path = template.replace("{x}", x.toString()).replace("{y}", y.toString()).replace("{z}", zoom.toString())
        return try {
          val bytes = if (model.useAssets && assets != null) {
            assets.open(path).use { it.readBytes() }
          } else {
            File(path).readBytes()
          }
          Tile(model.tileSize, model.tileSize, bytes)
        } catch (e: Exception) {
          TileProvider.NO_TILE
        }
      }
      override fun getTileWidth(): Int = model.tileSize
      override fun getTileHeight(): Int = model.tileSize
    }
    return aMap.addTileOverlay(TileOverlayOptions().tileProvider(provider).zIndex(model.zIndex))
  }

  private fun buildGroundOverlay(model: CnGroundOverlayModel): GroundOverlay? {
    val sw = model.southWest ?: return null
    val ne = model.northEast ?: return null
    val bmp = model.bitmap ?: return null
    return aMap.addGroundOverlay(
      GroundOverlayOptions()
        .positionFromBounds(LatLngBounds(LatLng(sw.latitude, sw.longitude), LatLng(ne.latitude, ne.longitude)))
        .image(BitmapDescriptorFactory.fromBitmap(bmp))
        .bearing(model.bearing)
        .transparency((1f - model.opacity).coerceIn(0f, 1f))
        .zIndex(model.zIndex)
    )
  }

  // Listeners -----------------------------------------------------------------

  private fun configureListeners() {
    aMap.setOnMapTouchListener { event ->
      if (event != null) {
        when (event.actionMasked) {
          MotionEvent.ACTION_DOWN -> isGesture = false
          MotionEvent.ACTION_MOVE -> isGesture = true
        }
        gestureDetector.onTouchEvent(event)
      }
    }

    aMap.setOnCameraChangeListener(object : AMap.OnCameraChangeListener {
      override fun onCameraChange(position: CameraPosition?) {
        delegate?.onRegionChange(complete = false, isGesture = isGesture)
      }
      override fun onCameraChangeFinish(position: CameraPosition?) {
        delegate?.onRegionChange(complete = true, isGesture = isGesture)
        isGesture = false
      }
    })

    aMap.setOnMapLoadedListener { delegate?.onMapReady() }

    aMap.setOnMapClickListener { latLng ->
      latLng?.let { delegate?.onMapPress(CnPressKind.PRESS, CnLatLng(it.latitude, it.longitude), screenPointFor(it)) }
    }

    aMap.setOnMapLongClickListener { latLng ->
      latLng?.let { delegate?.onMapPress(CnPressKind.LONG_PRESS, CnLatLng(it.latitude, it.longitude), screenPointFor(it)) }
    }

    aMap.setOnPOIClickListener { poi -> poi?.let { sendPoi(it) } }

    aMap.setOnMyLocationChangeListener { location ->
      location?.let {
        delegate?.onUserLocationChange(
          CnUserLocation(
            it.latitude, it.longitude, it.altitude, it.accuracy, it.speed, it.bearing, it.isFromMockProvider
          )
        )
      }
    }

    aMap.setOnMarkerClickListener { marker ->
      val handle = marker.`object` as? OverlayHandle
      val coordinate = CnLatLng(marker.position.latitude, marker.position.longitude)
      handle?.let {
        delegate?.onMarkerEvent(it.childId, CnMarkerEvent.PRESS, coordinate)
        delegate?.onMarkerEvent(it.childId, CnMarkerEvent.SELECT, coordinate)
      }
      // Show the info window only when there's content, then consume the click so
      // AMap does not re-center the map on the tapped marker (RNM parity).
      if (handle != null && (markerModels[handle]?.hasInfoWindowContent == true)) {
        marker.showInfoWindow()
      }
      true
    }

    aMap.setOnPolylineClickListener { clicked ->
      if (clicked != null) {
        overlayHandles.forEach { handle ->
          if (handle.sdkObject === clicked) {
            val model = overlayModels[handle]
            if (model is CnPolylineModel && model.tappable) {
              delegate?.onOverlayPress(handle.childId)
            }
          }
        }
      }
    }

    aMap.setOnMarkerDragListener(object : AMap.OnMarkerDragListener {
      override fun onMarkerDragStart(marker: Marker?) = deliverDrag(marker, CnMarkerEvent.DRAG_START)
      override fun onMarkerDrag(marker: Marker?) = deliverDrag(marker, CnMarkerEvent.DRAG)
      override fun onMarkerDragEnd(marker: Marker?) = deliverDrag(marker, CnMarkerEvent.DRAG_END)
    })

    aMap.setOnInfoWindowClickListener { marker ->
      val m = marker ?: return@setOnInfoWindowClickListener
      (m.`object` as? OverlayHandle)?.let {
        delegate?.onMarkerEvent(it.childId, CnMarkerEvent.CALLOUT_PRESS, CnLatLng(m.position.latitude, m.position.longitude))
      }
    }

    aMap.setInfoWindowAdapter(object : AMap.InfoWindowAdapter {
      override fun getInfoWindow(marker: Marker?): View? {
        val childId = (marker?.`object` as? OverlayHandle)?.childId ?: return null
        return delegate?.infoWindowViewFor(childId)
      }
      override fun getInfoContents(marker: Marker?): View? = null
    })
  }

  private fun deliverDrag(marker: Marker?, event: CnMarkerEvent) {
    val m = marker ?: return
    (m.`object` as? OverlayHandle)?.let {
      delegate?.onMarkerEvent(it.childId, event, CnLatLng(m.position.latitude, m.position.longitude))
    }
  }

  private fun sendPoi(poi: Poi) {
    val coordinate = poi.coordinate ?: return
    delegate?.onPoiClick(CnPoi(poi.poiId, poi.name, coordinate.latitude, coordinate.longitude))
  }

  private inner class GestureListener : GestureDetector.SimpleOnGestureListener() {
    override fun onDoubleTap(event: MotionEvent): Boolean {
      coordinateForTouch(event)?.let {
        delegate?.onMapPress(CnPressKind.DOUBLE_PRESS, it, Point(event.x.toInt(), event.y.toInt()))
      }
      return false
    }

    override fun onScroll(e1: MotionEvent?, e2: MotionEvent, distanceX: Float, distanceY: Float): Boolean {
      coordinateForTouch(e2)?.let {
        delegate?.onMapPress(CnPressKind.PAN_DRAG, it, Point(e2.x.toInt(), e2.y.toInt()))
      }
      return false
    }
  }

  // Helpers -------------------------------------------------------------------

  private fun applyPendingInitialCamera() {
    if (mapView.width <= 0 || mapView.height <= 0) return
    pendingInitialRegion?.let { region ->
      pendingInitialRegion = null
      didApplyInitialRegion = true
      moveToRegion(region, animated = false)
    }
    // A camera takes precedence over a region (RNM semantics).
    pendingInitialCamera?.let { camera ->
      pendingInitialCamera = null
      didApplyInitialCamera = true
      moveToCamera(camera, animated = false)
    }
  }

  private fun moveToRegion(region: CnRegion, animated: Boolean, duration: Int = 0) {
    val apply = Runnable {
      val boundsUpdate = CameraUpdateFactory.newLatLngBounds(regionToBounds(region), 0)
      runCatching { applyCameraUpdate(boundsUpdate, animated, duration) }.onFailure {
        applyCameraUpdate(
          CameraUpdateFactory.newLatLngZoom(LatLng(region.latitude, region.longitude), regionToZoom(region)),
          animated, duration
        )
      }
    }
    if (mapView.width <= 0 || mapView.height <= 0) mapView.post(apply) else apply.run()
  }

  private fun moveToCamera(camera: CnCamera, animated: Boolean, duration: Int = 0) {
    val apply = Runnable {
      val zoom = if (camera.zoom > 0) camera.zoom.toFloat() else aMap.cameraPosition.zoom
      val position = CameraPosition(
        LatLng(camera.latitude, camera.longitude), zoom, camera.pitch.toFloat(), camera.heading.toFloat()
      )
      applyCameraUpdate(CameraUpdateFactory.newCameraPosition(position), animated, duration)
    }
    if (mapView.width <= 0 || mapView.height <= 0) mapView.post(apply) else apply.run()
  }

  private fun applyCameraUpdate(update: CameraUpdate, animated: Boolean, duration: Int) {
    if (animated) aMap.animateCamera(update, duration.toLong(), null) else aMap.moveCamera(update)
  }

  private fun applyBounds(bounds: LatLngBounds, edgePadding: CnEdgeInsets, animated: Boolean) {
    val update = CameraUpdateFactory.newLatLngBoundsRect(
      bounds, edgePadding.left, edgePadding.right, edgePadding.top, edgePadding.bottom
    )
    val apply = Runnable { applyCameraUpdate(update, animated, 300) }
    if (mapView.width <= 0 || mapView.height <= 0) mapView.post(apply) else apply.run()
  }

  private fun coordinateForTouch(event: MotionEvent): CnLatLng? =
    runCatching { aMap.projection.fromScreenLocation(Point(event.x.toInt(), event.y.toInt())) }
      .getOrNull()?.let { CnLatLng(it.latitude, it.longitude) }

  private fun screenPointFor(coordinate: LatLng): Point? =
    runCatching { aMap.projection.toScreenLocation(coordinate) }.getOrNull()

  private fun regionToBounds(region: CnRegion): LatLngBounds {
    val halfLat = max(region.latitudeDelta, MIN_DELTA) / 2.0
    val halfLon = max(region.longitudeDelta, MIN_DELTA) / 2.0
    val southwest = LatLng(max(-90.0, region.latitude - halfLat), max(-180.0, region.longitude - halfLon))
    val northeast = LatLng(min(90.0, region.latitude + halfLat), min(180.0, region.longitude + halfLon))
    return LatLngBounds(southwest, northeast)
  }

  private fun regionToZoom(region: CnRegion): Float {
    val delta = max(max(region.latitudeDelta, region.longitudeDelta), MIN_DELTA)
    return (ln(360.0 / delta) / ln(2.0)).toFloat().coerceIn(3f, 20f)
  }

  private fun markerHue(color: String?): Float? {
    if (color == null) return null
    return runCatching {
      val hsv = FloatArray(3)
      Color.colorToHSV(Color.parseColor(color), hsv)
      hsv[0]
    }.getOrNull()
  }

  // RNM rotation is clockwise degrees; AMap's rotateAngle is counterclockwise.
  private fun rnRotationToAMap(degrees: Float): Float {
    val normalized = (360f - (degrees % 360f)) % 360f
    return if (normalized < 0f) normalized + 360f else normalized
  }

  private fun polylineLineCap(lineCap: String?): PolylineOptions.LineCapType? = when (lineCap) {
    "butt" -> PolylineOptions.LineCapType.LineCapButt
    "round" -> PolylineOptions.LineCapType.LineCapRound
    "square" -> PolylineOptions.LineCapType.LineCapSquare
    else -> null
  }

  private fun polylineLineJoin(lineJoin: String?): PolylineOptions.LineJoinType? = when (lineJoin) {
    "miter" -> PolylineOptions.LineJoinType.LineJoinMiter
    "round" -> PolylineOptions.LineJoinType.LineJoinRound
    "bevel" -> PolylineOptions.LineJoinType.LineJoinBevel
    else -> null
  }

  private fun wmsUrl(template: String, x: Int, y: Int, zoom: Int, tileSize: Int): String {
    val m = 20037508.342789244
    val tileMeters = (2 * m) / (1 shl zoom)
    val minX = -m + x * tileMeters
    val maxX = -m + (x + 1) * tileMeters
    val maxY = m - y * tileMeters
    val minY = m - (y + 1) * tileMeters
    return template
      .replace("{minX}", minX.toString())
      .replace("{minY}", minY.toString())
      .replace("{maxX}", maxX.toString())
      .replace("{maxY}", maxY.toString())
      .replace("{width}", tileSize.toString())
      .replace("{height}", tileSize.toString())
  }

  private companion object {
    private const val MIN_DELTA = 0.000001
  }
}

// Factory + privacy entry point registered with CnMapAdapterRegistry.
object AMapAdapterFactory : CnMapAdapterFactory {
  override fun create(context: Context): CnMapAdapter = AMapAdapter(context)

  override fun applyPrivacyConsent(context: Context, agreed: Boolean, contains: Boolean, shown: Boolean) {
    MapsInitializer.updatePrivacyShow(context, contains, shown)
    MapsInitializer.updatePrivacyAgree(context, agreed)
  }
}
