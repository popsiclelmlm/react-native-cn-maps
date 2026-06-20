package com.cnmaps.adapter

import android.graphics.Point
import android.view.View

// The provider-agnostic contract the core host (MapView) talks to. A concrete
// adapter (e.g. AMapAdapter) owns the real SDK map view, its listeners and all SDK
// calls; the host owns Fabric/ViewGroup lifecycle, child routing and event
// dispatch. No method here exposes a provider (AMap) or codegen type.
interface CnMapAdapter {
  // The view to add into the host FrameLayout.
  val view: View
  var delegate: CnMapAdapterDelegate?

  // Lifecycle (the host forwards these from its own lifecycle/size callbacks).
  fun onResume()
  fun onPause()
  fun onDestroy()
  fun onSizeChanged()

  // Configuration -------------------------------------------------------------
  fun setMapType(value: String?)
  fun setUserInterfaceStyle(value: String?)
  fun setMinZoomLevel(value: Double)
  fun setMaxZoomLevel(value: Double)
  fun setZoomEnabled(value: Boolean)
  fun setZoomControlEnabled(value: Boolean)
  fun setScrollEnabled(value: Boolean)
  fun setRotateEnabled(value: Boolean)
  fun setPitchEnabled(value: Boolean)
  fun setShowsUserLocation(value: Boolean)
  fun setShowsMyLocationButton(value: Boolean)
  fun setShowsCompass(value: Boolean)
  fun setShowsScale(value: Boolean)
  fun setShowsTraffic(value: Boolean)
  fun setShowsBuildings(value: Boolean)
  fun setShowsIndoors(value: Boolean)
  fun setShowsIndoorLevelPicker(value: Boolean)
  fun setShowsPointsOfInterest(value: Boolean)

  // Viewport ------------------------------------------------------------------
  fun setInitialRegion(region: CnRegion)
  fun setRegion(region: CnRegion)
  fun setInitialCamera(camera: CnCamera)
  fun setCamera(camera: CnCamera)
  fun animateToRegion(region: CnRegion, duration: Int)
  fun applyCamera(camera: CnCamera, animated: Boolean, duration: Int)
  fun currentRegion(): CnRegion?
  fun currentCamera(): CnCamera
  // northeast / southwest of the visible region, or null if unavailable.
  fun mapBoundaries(): Pair<CnLatLng, CnLatLng>?
  fun fitToCoordinates(coordinates: List<CnLatLng>, edgePadding: CnEdgeInsets, animated: Boolean)
  fun fitToMarkers(handles: List<OverlayHandle>, edgePadding: CnEdgeInsets, animated: Boolean)
  fun setMapBoundaries(ne: CnLatLng, sw: CnLatLng)

  // Projection (px; the host applies density). ---------------------------------
  fun pointForCoordinate(coordinate: CnLatLng): Point?
  fun coordinateForPoint(xPx: Int, yPx: Int): CnLatLng?

  // Snapshot (async; replies with a file:// uri / base64 / "" on failure). -----
  fun takeSnapshot(
    width: Int,
    height: Int,
    format: String,
    quality: Double,
    result: String,
    completion: (uri: String) -> Unit
  )

  // Markers -------------------------------------------------------------------
  fun addMarker(model: CnMarkerModel, childId: String): OverlayHandle
  fun updateMarker(handle: OverlayHandle, model: CnMarkerModel)
  fun removeMarker(handle: OverlayHandle)
  fun showCallout(handle: OverlayHandle)
  fun hideCallout(handle: OverlayHandle)
  fun redrawCallout(handle: OverlayHandle)
  fun animateMarker(handle: OverlayHandle, latitude: Double, longitude: Double, duration: Int)
  fun markerScreenPoint(handle: OverlayHandle): Point?
  fun markerPosition(handle: OverlayHandle): CnLatLng?

  // Overlays ------------------------------------------------------------------
  fun addOverlay(model: CnOverlayModel, childId: String): OverlayHandle
  fun updateOverlay(handle: OverlayHandle, model: CnOverlayModel)
  fun removeOverlay(handle: OverlayHandle)
}

// A factory + privacy entry point a provider package registers. Kept separate from
// the per-map adapter so the registry can create maps and fan privacy out without
// a live map instance.
interface CnMapAdapterFactory {
  fun create(context: android.content.Context): CnMapAdapter
  fun applyPrivacyConsent(context: android.content.Context, agreed: Boolean, contains: Boolean, shown: Boolean)
}
