package com.cnmaps

import android.animation.ValueAnimator
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.FrameLayout
import com.amap.api.maps.AMap
import com.amap.api.maps.model.BitmapDescriptor
import com.amap.api.maps.model.BitmapDescriptorFactory
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.Marker
import com.amap.api.maps.model.MarkerOptions
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import java.net.URL

/**
 * Fabric child host component (`RNMapsMarker`) mounted under `MapView`. The view
 * never participates in the FrameLayout's normal layout — the parent `MapView`
 * intercepts its add/remove (via the manager's ViewGroup overrides) and turns it
 * into an AMap `Marker`. The created marker stores this view in `marker.object`
 * so the map's click listener can route callbacks back here.
 */
class MarkerView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext) {
  var identifier: String? = null

  // latitude/longitude arrive as two independent flattened props; each setter
  // pushes the combined position to the live marker once it exists.
  var markerLatitude: Double = 0.0
    set(value) {
      field = value
      marker?.position = LatLng(value, markerLongitude)
    }
  var markerLongitude: Double = 0.0
    set(value) {
      field = value
      marker?.position = LatLng(markerLatitude, value)
    }

  private var title: String? = null
  private var snippet: String? = null
  private var pinColor: String? = null
  private var draggable: Boolean = false

  // Appearance (PR-2). centerOffset/calloutAnchor are iOS positioning hooks with
  // no AMap-Android equivalent, so they are accepted (in the manager) but ignored
  // here; `anchor` is the Android positioning hook.
  private var anchorU: Float = 0.5f
  private var anchorV: Float = 1.0f
  private var opacity: Float = 1.0f
  private var rotation: Float = 0.0f
  private var flat: Boolean = false
  private var zIndexValue: Float = 0.0f
  private var imageUri: String? = null
  private var iconBitmap: Bitmap? = null

  // Custom React content (PR-3): children render into this FrameLayout offscreen
  // and are rasterized into the marker icon.
  private var tracksViewChanges: Boolean = true
  private var tracksInfoWindowChanges: Boolean = false
  private var customBitmap: Bitmap? = null
  private var didRender: Boolean = false
  private var renderScheduled: Boolean = false

  private var marker: Marker? = null
  private var positionAnimator: ValueAnimator? = null

  // Fabric child reconciliation list (PR-4 callout). Regular content children also
  // live in the FrameLayout (for icon rasterization); the <Callout> child is held
  // here but kept OUT of the FrameLayout so it can be handed, parent-less, to
  // AMap's InfoWindowAdapter.
  private val reactChildren = ArrayList<View>()
  private var calloutView: CalloutView? = null

  fun setMarkerTitle(value: String?) {
    title = value
    marker?.title = value ?: ""
  }

  fun setMarkerSnippet(value: String?) {
    snippet = value
    marker?.snippet = value ?: ""
  }

  fun setPinColor(value: String?) {
    pinColor = value
    marker?.let { applyIcon(it) }
  }

  fun setMarkerDraggable(value: Boolean) {
    draggable = value
    marker?.isDraggable = value
  }

  fun setAnchorPoint(u: Float, v: Float) {
    anchorU = u
    anchorV = v
    marker?.setAnchor(u, v)
  }

  fun setOpacity(value: Float) {
    opacity = value
    marker?.alpha = value
  }

  fun setRotationDegrees(value: Float) {
    rotation = value
    marker?.rotateAngle = rnRotationToAMap(value)
  }

  fun setFlatMarker(value: Boolean) {
    flat = value
    marker?.isFlat = value
  }

  fun setZIndexValue(value: Float) {
    zIndexValue = value
    marker?.zIndex = value
  }

  fun setImage(uri: String?) {
    val normalized = if (uri.isNullOrEmpty()) null else uri
    if (normalized == imageUri) {
      return
    }

    imageUri = normalized
    if (normalized == null) {
      iconBitmap = null
      marker?.let { applyIcon(it) }
      return
    }

    loadImage(normalized)
  }

  fun setTracksViewChanges(value: Boolean) {
    if (value && !tracksViewChanges) {
      // Re-enabling: allow at least one fresh render again.
      didRender = false
    }
    tracksViewChanges = value
    scheduleRender()
  }

  fun setTracksInfoWindowChanges(value: Boolean) {
    // Accepted for RNM parity; the system info window has no React content to
    // re-rasterize in this milestone (real <Callout> content lands in M4).
    tracksInfoWindowChanges = value
  }

  // Parent-driven attachment ---------------------------------------------------

  fun attachTo(aMap: AMap) {
    if (marker != null) {
      return
    }

    val options = MarkerOptions()
      .position(LatLng(markerLatitude, markerLongitude))
      .draggable(draggable)
      .anchor(anchorU, anchorV)
      .alpha(opacity)
      .setFlat(flat)
      .rotateAngle(rnRotationToAMap(rotation))
      .zIndex(zIndexValue)
      .icon(currentDescriptor())
    title?.let { options.title(it) }
    snippet?.let { options.snippet(it) }

    val created = aMap.addMarker(options)
    created.`object` = this
    marker = created
  }

  fun detach() {
    positionAnimator?.cancel()
    positionAnimator = null
    marker?.remove()
    marker = null
  }

  // Fabric child reconciliation (driven by MarkerManager's ViewGroup overrides) --

  fun addReactChild(child: View, index: Int) {
    reactChildren.add(index.coerceIn(0, reactChildren.size), child)
    if (child is CalloutView) {
      // Kept out of the FrameLayout so it can be handed parent-less to the
      // InfoWindowAdapter (and excluded from the marker-icon rasterization).
      calloutView = child
    } else {
      addView(child)
    }
  }

  fun removeReactChildAt(index: Int) {
    if (index < 0 || index >= reactChildren.size) {
      return
    }

    val child = reactChildren.removeAt(index)
    if (child is CalloutView) {
      if (child === calloutView) {
        calloutView = null
      }
    } else {
      removeView(child)
    }
  }

  fun getReactChildCount(): Int = reactChildren.size

  fun getReactChildAt(index: Int): View = reactChildren[index]

  // Handed to AMap's InfoWindowAdapter; null → AMap shows the default title/snippet
  // window.
  fun getCalloutView(): View? = calloutView

  fun onInfoWindowClicked() {
    emitCalloutPress()
    calloutView?.emitPress()
  }

  // Commands -------------------------------------------------------------------

  fun showCallout() {
    marker?.showInfoWindow()
  }

  fun hideCallout() {
    marker?.hideInfoWindow()
  }

  fun redrawCallout() {
    marker?.let { if (it.isInfoWindowShown) it.showInfoWindow() }
  }

  fun redraw() {
    if (hasCustomContent()) {
      didRender = false
      scheduleRender()
    }
  }

  fun animateToCoordinate(latitude: Double, longitude: Double, duration: Int) {
    val target = marker ?: return
    positionAnimator?.cancel()

    val start = target.position
    val end = LatLng(latitude, longitude)
    if (duration <= 0) {
      target.position = end
      return
    }

    positionAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
      this.duration = duration.toLong()
      addUpdateListener { animation ->
        val t = animation.animatedValue as Float
        marker?.position = LatLng(
          start.latitude + (end.latitude - start.latitude) * t,
          start.longitude + (end.longitude - start.longitude) * t
        )
      }
      start()
    }
  }

  // Events ---------------------------------------------------------------------

  fun emitPress() = emitCoordinateEvent("topPress")

  fun emitSelect() = emitCoordinateEvent("topSelect")

  fun emitDeselect() = emitCoordinateEvent("topDeselect")

  fun emitCalloutPress() = emitCoordinateEvent("topCalloutPress")

  fun emitDragStart() = emitCoordinateEvent("topDragStart")

  fun emitDrag() = emitCoordinateEvent("topDrag")

  fun emitDragEnd() = emitCoordinateEvent("topDragEnd")

  private fun emitCoordinateEvent(eventName: String) {
    if (id == NO_ID) {
      return
    }

    val position = marker?.position ?: LatLng(markerLatitude, markerLongitude)
    UIManagerHelper.getEventDispatcher(reactContext)?.dispatchEvent(
      MarkerCoordinateEvent(
        UIManagerHelper.getSurfaceId(this),
        id,
        eventName,
        position.latitude,
        position.longitude
      )
    )
  }

  private fun applyIcon(target: Marker) {
    target.setIcon(currentDescriptor())
  }

  // Priority: rasterized custom React content > loaded `image` bitmap >
  // hue-tinted default pin > plain default marker.
  private fun currentDescriptor(): BitmapDescriptor {
    customBitmap?.let { return BitmapDescriptorFactory.fromBitmap(it) }
    iconBitmap?.let { return BitmapDescriptorFactory.fromBitmap(it) }

    val hue = markerHue(pinColor)
    return if (hue != null) {
      BitmapDescriptorFactory.defaultMarker(hue)
    } else {
      BitmapDescriptorFactory.defaultMarker()
    }
  }

  private fun hasCustomContent(): Boolean = childCount > 0

  override fun onViewAdded(child: View) {
    super.onViewAdded(child)
    didRender = false
    scheduleRender()
  }

  override fun onViewRemoved(child: View) {
    super.onViewRemoved(child)
    if (!hasCustomContent()) {
      // Reverted to a plain marker: drop the rasterized icon.
      customBitmap = null
      didRender = false
      marker?.let { applyIcon(it) }
    } else {
      didRender = false
      scheduleRender()
    }
  }

  override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
    super.onLayout(changed, l, t, r, b)
    scheduleRender()
  }

  override fun requestLayout() {
    super.requestLayout()
    // A child's content/size change requests layout; re-rasterize afterwards.
    scheduleRender()
  }

  // Debounce: collapse the layout/requestLayout bursts into a single render that
  // runs once the subtree has settled for this frame.
  private fun scheduleRender() {
    if (renderScheduled || !hasCustomContent()) {
      return
    }

    renderScheduled = true
    post {
      renderScheduled = false
      renderCustomIfNeeded()
    }
  }

  private fun renderCustomIfNeeded() {
    if (!hasCustomContent() || width <= 0 || height <= 0) {
      return
    }
    if (!tracksViewChanges && didRender) {
      return
    }

    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    draw(Canvas(bitmap))
    customBitmap = bitmap
    didRender = true
    marker?.let { applyIcon(it) }
  }

  // Best-effort, dependency-free decode: http(s) over the network (covers the
  // Metro-served dev asset uri), file:// from disk, otherwise a drawable resource
  // name. Decoding runs off the UI thread; the result is applied back on it.
  private fun loadImage(uri: String) {
    Thread {
      val bitmap = runCatching {
        when {
          uri.startsWith("http://") || uri.startsWith("https://") ->
            URL(uri).openStream().use { BitmapFactory.decodeStream(it) }
          uri.startsWith("file://") ->
            BitmapFactory.decodeFile(Uri.parse(uri).path)
          else -> {
            val resId = resources.getIdentifier(uri, "drawable", context.packageName)
            if (resId != 0) BitmapFactory.decodeResource(resources, resId) else null
          }
        }
      }.getOrNull()

      post {
        // Ignore a stale load if the uri changed again before it resolved.
        if (uri == imageUri) {
          iconBitmap = bitmap
          marker?.let { applyIcon(it) }
        }
      }
    }.start()
  }

  private fun markerHue(color: String?): Float? {
    if (color == null) {
      return null
    }

    return runCatching {
      val hsv = FloatArray(3)
      Color.colorToHSV(Color.parseColor(color), hsv)
      hsv[0]
    }.getOrNull()
  }

  // RNM rotation is clockwise degrees; AMap's rotateAngle is counterclockwise, so
  // invert and normalize into [0, 360).
  private fun rnRotationToAMap(degrees: Float): Float {
    val normalized = (360f - (degrees % 360f)) % 360f
    return if (normalized < 0f) normalized + 360f else normalized
  }

  // Shared by all marker events; the RNM facade re-attaches the identifier.
  private class MarkerCoordinateEvent(
    surfaceId: Int,
    viewId: Int,
    private val rnEventName: String,
    private val latitude: Double,
    private val longitude: Double
  ) : Event<MarkerCoordinateEvent>(surfaceId, viewId) {
    override fun getEventName(): String = rnEventName

    // onDrag fires continuously; allow coalescing to avoid flooding the bridge.
    override fun canCoalesce(): Boolean = rnEventName == "topDrag"

    override fun getEventData(): WritableMap =
      Arguments.createMap().apply {
        putMap(
          "coordinate",
          Arguments.createMap().apply {
            putDouble("latitude", latitude)
            putDouble("longitude", longitude)
          }
        )
      }
  }
}
