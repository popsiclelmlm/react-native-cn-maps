package com.cnmaps.adapter

import android.graphics.Bitmap

// Provider-agnostic value types shared between the core host/children and a map
// provider adapter. Nothing here references the AMap SDK or the codegen types.

data class CnLatLng(val latitude: Double, val longitude: Double)

data class CnRegion(
  val latitude: Double,
  val longitude: Double,
  val latitudeDelta: Double,
  val longitudeDelta: Double
)

data class CnCamera(
  val latitude: Double,
  val longitude: Double,
  val heading: Double,
  val pitch: Double,
  val zoom: Double,
  val altitude: Double
)

data class CnEdgeInsets(val top: Int, val right: Int, val bottom: Int, val left: Int) {
  companion object {
    val ZERO = CnEdgeInsets(0, 0, 0, 0)
  }
}

// Marker model. The marker icon is rasterized (custom React children) / decoded
// (image prop) into Bitmaps by the dumb child (provider-agnostic) and handed over
// ready to use; the adapter only turns them into a provider BitmapDescriptor.
data class CnMarkerModel(
  val identifier: String?,
  val latitude: Double,
  val longitude: Double,
  val title: String?,
  val snippet: String?,
  val pinColor: String?,
  val draggable: Boolean,
  val anchorU: Float,
  val anchorV: Float,
  val opacity: Float,
  val rotation: Float, // RNM clockwise degrees; the adapter converts to provider angle
  val flat: Boolean,
  val zIndex: Float,
  val customBitmap: Bitmap?, // rasterized custom React children
  val iconBitmap: Bitmap?,   // decoded `image` prop
  val hasInfoWindowContent: Boolean
)

// Overlay models. The adapter switches on the concrete type and builds the SDK
// overlay + its options.
sealed class CnOverlayModel

data class CnPolylineModel(
  val coordinates: List<CnLatLng>,
  val strokeColor: Int,
  val strokeColors: List<Int>,
  val strokeWidth: Float,
  val zIndex: Float,
  val geodesic: Boolean,
  val dashed: Boolean,
  val lineCap: String?,
  val lineJoin: String?,
  val tappable: Boolean
) : CnOverlayModel()

data class CnPolygonModel(
  val coordinates: List<CnLatLng>,
  val holes: List<List<CnLatLng>>,
  val strokeColor: Int,
  val fillColor: Int,
  val strokeWidth: Float,
  val zIndex: Float
) : CnOverlayModel()

data class CnCircleModel(
  val center: CnLatLng,
  val radius: Double,
  val strokeColor: Int,
  val fillColor: Int,
  val strokeWidth: Float,
  val zIndex: Float
) : CnOverlayModel()

data class CnHeatmapWeightedPoint(val latitude: Double, val longitude: Double, val weight: Double)

data class CnHeatmapModel(
  val points: List<CnHeatmapWeightedPoint>,
  val radius: Int,
  val gradientColors: IntArray?,
  val gradientStartPoints: FloatArray?
) : CnOverlayModel()

data class CnUrlTileModel(
  val urlTemplate: String?,
  val minimumZ: Int,
  val maximumZ: Int,
  val tileSize: Int,
  val flipY: Boolean,
  val wms: Boolean,
  val zIndex: Float,
  val diskCacheDir: String?
) : CnOverlayModel()

data class CnLocalTileModel(
  val pathTemplate: String?,
  val tileSize: Int,
  val useAssets: Boolean,
  val zIndex: Float
) : CnOverlayModel()

data class CnGroundOverlayModel(
  val southWest: CnLatLng?,
  val northEast: CnLatLng?,
  val bitmap: Bitmap?,
  val bearing: Float,
  val opacity: Float,
  val zIndex: Float
) : CnOverlayModel()

// Point-of-interest tapped on the basemap.
data class CnPoi(
  val placeId: String?,
  val name: String?,
  val latitude: Double,
  val longitude: Double
)

// User-location snapshot surfaced to the host (provider-agnostic scalars).
data class CnUserLocation(
  val latitude: Double,
  val longitude: Double,
  val altitude: Double,
  val accuracy: Float,
  val speed: Float,
  val heading: Float,
  val isFromMockProvider: Boolean
)

// Map-level press kinds that share the { coordinate, position } payload.
enum class CnPressKind { PRESS, LONG_PRESS, DOUBLE_PRESS, PAN_DRAG }

// Marker callbacks the adapter routes back to a child by childId.
enum class CnMarkerEvent { PRESS, SELECT, DESELECT, CALLOUT_PRESS, DRAG_START, DRAG, DRAG_END }
