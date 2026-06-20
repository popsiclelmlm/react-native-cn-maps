package com.cnmaps

import android.widget.FrameLayout
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event

/**
 * Child host component of [MarkerView]. Hosts the `<Callout>` React subtree and is
 * handed to AMap's InfoWindowAdapter as the marker's info window (AMap renders it
 * as a snapshot, so it must stay detached from any parent — see [MarkerView]).
 */
class CalloutView(private val reactContext: ThemedReactContext) :
  FrameLayout(reactContext) {
  var tooltip: Boolean = false

  fun emitPress() {
    if (id == NO_ID) {
      return
    }

    UIManagerHelper.getEventDispatcher(reactContext)?.dispatchEvent(
      CalloutPressEvent(UIManagerHelper.getSurfaceId(this), id)
    )
  }

  private class CalloutPressEvent(surfaceId: Int, viewId: Int) :
    Event<CalloutPressEvent>(surfaceId, viewId) {
    override fun getEventName(): String = "topPress"

    override fun canCoalesce(): Boolean = false

    override fun getEventData(): WritableMap = Arguments.createMap()
  }
}
