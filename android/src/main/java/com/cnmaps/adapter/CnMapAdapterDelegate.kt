package com.cnmaps.adapter

import android.graphics.Point
import android.view.View

// Adapter → host callbacks. The adapter owns the provider's map + listeners and
// translates them into these provider-agnostic ones. On Android the touch stream
// is provider-bound (aMap.setOnMapTouchListener), so — unlike iOS — gesture-based
// presses (double tap / pan) also flow through here.
interface CnMapAdapterDelegate {
  fun onMapReady()

  // Map-level press. `screenPoint` is in px (the host converts to dp).
  fun onMapPress(kind: CnPressKind, coordinate: CnLatLng, screenPoint: Point?)

  // `complete` distinguishes the in-flight (onRegionChange) from the settled callback.
  fun onRegionChange(complete: Boolean, isGesture: Boolean)

  fun onPoiClick(poi: CnPoi)

  fun onUserLocationChange(location: CnUserLocation)

  // Marker callbacks, routed back to the owning child by childId. The coordinate is
  // the marker's current position (so drag end carries the dropped location).
  fun onMarkerEvent(childId: String, event: CnMarkerEvent, coordinate: CnLatLng)

  // A tappable overlay (polyline) was clicked.
  fun onOverlayPress(childId: String)

  // The adapter's InfoWindowAdapter needs the child's custom callout View, if any.
  fun infoWindowViewFor(childId: String): View?
}
