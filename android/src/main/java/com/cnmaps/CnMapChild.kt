package com.cnmaps

import android.view.View
import com.cnmaps.adapter.CnMapAdapter
import com.cnmaps.adapter.CnOverlayModel
import com.cnmaps.adapter.OverlayHandle

// Implemented by [MapView]. A child calls onChildModelChanged when its model
// changes (a prop diff or an async image load / rasterization); the host re-applies
// it through the adapter. This replaces the old pattern where the child mutated the
// SDK map directly. mapAdapter lets a child route its imperative commands (e.g.
// marker showCallout) through the provider-agnostic adapter without touching any
// SDK type.
interface CnMapHost {
  fun onChildModelChanged(child: View)
  val mapAdapter: CnMapAdapter?
}

// Common bookkeeping the host sets on every child feature it tracks.
interface CnMapFeature {
  var cnChildId: String?
  var cnHandle: OverlayHandle?
  var mapHost: CnMapHost?
}

// Overlay children (polyline/polygon/circle/heatmap/tiles/ground) expose a model;
// markers are handled separately by the host (they are not overlays).
interface CnOverlayFeature : CnMapFeature {
  fun overlayModel(): CnOverlayModel
}
