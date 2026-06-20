package com.cnmaps.adapter

// Opaque token returned by the adapter when a marker/overlay is added, and handed
// back for later update/remove. The host keeps it on the child; only the adapter
// that created it knows what `sdkObject` concretely is, keeping this file
// provider-agnostic.
class OverlayHandle(val childId: String) {
  var sdkObject: Any? = null
}
