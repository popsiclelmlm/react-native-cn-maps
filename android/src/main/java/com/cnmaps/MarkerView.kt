package com.cnmaps

import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import com.cnmaps.adapter.CnMarkerEvent
import com.cnmaps.adapter.CnMarkerModel
import com.cnmaps.adapter.OverlayHandle
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event

/**
 * Provider-agnostic Fabric child host component (`RNMapsMarker`). It produces a
 * [CnMarkerModel] and does the Android-side work (image decode, offscreen
 * rasterization of custom React children) but never touches the SDK map — the
 * adapter owns the marker. Prop/content changes are pushed to the host, which
 * re-applies the model through the adapter.
 */
class MarkerView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext), CnMapFeature {
  override var cnChildId: String? = null
  override var cnHandle: OverlayHandle? = null
  override var mapHost: CnMapHost? = null

  var identifier: String? = null

  var markerLatitude: Double = 0.0
    set(value) { field = value; notifyHost() }
  var markerLongitude: Double = 0.0
    set(value) { field = value; notifyHost() }

  private var title: String? = null
  private var snippet: String? = null
  private var pinColor: String? = null
  private var draggable: Boolean = false
  private var anchorU: Float = 0.5f
  private var anchorV: Float = 1.0f
  private var opacity: Float = 1.0f
  private var rotation: Float = 0.0f
  private var flat: Boolean = false
  private var zIndexValue: Float = 0.0f
  private var imageUri: String? = null
  private var iconBitmap: Bitmap? = null

  private var tracksViewChanges: Boolean = true
  private var customBitmap: Bitmap? = null
  private var didRender: Boolean = false
  private var renderScheduled: Boolean = false

  // This view is intercepted by the map and never attached to a window, so
  // View.post {} would never run — schedule on the main looper directly.
  private val mainHandler = Handler(Looper.getMainLooper())

  private val reactChildren = ArrayList<View>()
  private var calloutView: CalloutView? = null

  // Model ----------------------------------------------------------------------

  fun markerModel(): CnMarkerModel = CnMarkerModel(
    identifier = identifier,
    latitude = markerLatitude,
    longitude = markerLongitude,
    title = title,
    snippet = snippet,
    pinColor = pinColor,
    draggable = draggable,
    anchorU = anchorU,
    anchorV = anchorV,
    opacity = opacity,
    rotation = rotation,
    flat = flat,
    zIndex = zIndexValue,
    customBitmap = if (hasCustomContent()) customBitmap else null,
    iconBitmap = iconBitmap,
    hasInfoWindowContent = calloutView != null || !title.isNullOrEmpty()
  )

  private fun notifyHost() {
    mapHost?.onChildModelChanged(this)
  }

  // Props ----------------------------------------------------------------------

  fun setMarkerTitle(value: String?) { title = value; notifyHost() }
  fun setMarkerSnippet(value: String?) { snippet = value; notifyHost() }
  fun setPinColor(value: String?) { pinColor = value; notifyHost() }
  fun setMarkerDraggable(value: Boolean) { draggable = value; notifyHost() }
  fun setAnchorPoint(u: Float, v: Float) { anchorU = u; anchorV = v; notifyHost() }
  fun setOpacity(value: Float) { opacity = value; notifyHost() }
  fun setRotationDegrees(value: Float) { rotation = value; notifyHost() }
  fun setFlatMarker(value: Boolean) { flat = value; notifyHost() }
  fun setZIndexValue(value: Float) { zIndexValue = value; notifyHost() }

  fun setImage(uri: String?) {
    val normalized = if (uri.isNullOrEmpty()) null else uri
    if (normalized == imageUri) {
      return
    }
    imageUri = normalized
    if (normalized == null) {
      recycle(iconBitmap)
      iconBitmap = null
      notifyHost()
      return
    }
    loadImage(normalized)
  }

  fun setTracksViewChanges(value: Boolean) {
    if (value && !tracksViewChanges) {
      didRender = false
    }
    tracksViewChanges = value
    scheduleRender()
  }

  fun setTracksInfoWindowChanges(value: Boolean) {
    // Accepted for RNM parity; the custom <Callout> renders via the adapter's
    // InfoWindowAdapter and has no separate re-rasterization here.
  }

  // Fabric child reconciliation (driven by MarkerManager's ViewGroup overrides) -

  fun addReactChild(child: View, index: Int) {
    reactChildren.add(index.coerceIn(0, reactChildren.size), child)
    if (child is CalloutView) {
      calloutView = child
      notifyHost()
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
        notifyHost()
      }
    } else {
      removeView(child)
    }
  }

  fun getReactChildCount(): Int = reactChildren.size
  fun getReactChildAt(index: Int): View = reactChildren[index]

  // Pulled by the adapter's InfoWindowAdapter (via the host) at show time.
  fun getCalloutView(): View? = calloutView

  // Commands -------------------------------------------------------------------

  fun showCallout() { cnHandle?.let { mapHost?.mapAdapter?.showCallout(it) } }
  fun hideCallout() { cnHandle?.let { mapHost?.mapAdapter?.hideCallout(it) } }
  fun redrawCallout() { cnHandle?.let { mapHost?.mapAdapter?.redrawCallout(it) } }

  fun redraw() {
    if (hasCustomContent()) {
      didRender = false
      scheduleRender()
    }
  }

  fun animateToCoordinate(latitude: Double, longitude: Double, duration: Int) {
    cnHandle?.let { mapHost?.mapAdapter?.animateMarker(it, latitude, longitude, duration) }
  }

  // Events ---------------------------------------------------------------------

  fun emitMarkerEvent(event: CnMarkerEvent, latitude: Double, longitude: Double) {
    when (event) {
      CnMarkerEvent.PRESS -> emitCoordinateEvent("topPress", latitude, longitude)
      CnMarkerEvent.SELECT -> emitCoordinateEvent("topSelect", latitude, longitude)
      CnMarkerEvent.DESELECT -> emitCoordinateEvent("topDeselect", latitude, longitude)
      CnMarkerEvent.CALLOUT_PRESS -> {
        emitCoordinateEvent("topCalloutPress", latitude, longitude)
        calloutView?.emitPress()
      }
      CnMarkerEvent.DRAG_START -> emitCoordinateEvent("topDragStart", latitude, longitude)
      CnMarkerEvent.DRAG -> emitCoordinateEvent("topDrag", latitude, longitude)
      CnMarkerEvent.DRAG_END -> emitCoordinateEvent("topDragEnd", latitude, longitude)
    }
  }

  private fun emitCoordinateEvent(eventName: String, latitude: Double, longitude: Double) {
    if (id == NO_ID) {
      return
    }
    UIManagerHelper.getEventDispatcher(reactContext)?.dispatchEvent(
      MarkerCoordinateEvent(UIManagerHelper.getSurfaceId(this), id, eventName, latitude, longitude)
    )
  }

  // Custom React content rasterization ----------------------------------------

  private fun hasCustomContent(): Boolean = childCount > 0

  override fun onViewAdded(child: View) {
    super.onViewAdded(child)
    didRender = false
    scheduleRender()
  }

  override fun onViewRemoved(child: View) {
    super.onViewRemoved(child)
    if (!hasCustomContent()) {
      recycle(customBitmap)
      customBitmap = null
      didRender = false
      notifyHost()
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
    scheduleRender()
  }

  private fun scheduleRender() {
    if (renderScheduled || !hasCustomContent()) {
      return
    }
    renderScheduled = true
    mainHandler.post {
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
    val previous = customBitmap
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    draw(Canvas(bitmap))
    customBitmap = bitmap
    didRender = true
    notifyHost()
    // The adapter copies the bitmap into a descriptor synchronously above, so the
    // previous frame is safe to free now (parity with the old F1 handling).
    if (previous !== bitmap) {
      recycle(previous)
    }
  }

  private fun loadImage(uri: String) {
    MapsImageLoader.executor.execute {
      val bitmap = MapsImageLoader.decode(uri, resources, context.packageName)
      mainHandler.post {
        if (uri == imageUri) {
          val previous = iconBitmap
          iconBitmap = bitmap
          notifyHost()
          if (previous !== bitmap) {
            recycle(previous)
          }
        } else {
          recycle(bitmap)
        }
      }
    }
  }

  private fun recycle(bitmap: Bitmap?) {
    if (bitmap != null && !bitmap.isRecycled) {
      bitmap.recycle()
    }
  }

  private class MarkerCoordinateEvent(
    surfaceId: Int,
    viewId: Int,
    private val rnEventName: String,
    private val latitude: Double,
    private val longitude: Double
  ) : Event<MarkerCoordinateEvent>(surfaceId, viewId) {
    override fun getEventName(): String = rnEventName
    override fun canCoalesce(): Boolean = rnEventName == "topDrag"
    override fun getEventData(): WritableMap =
      Arguments.createMap().apply {
        putMap("coordinate", Arguments.createMap().apply {
          putDouble("latitude", latitude)
          putDouble("longitude", longitude)
        })
      }
  }
}
