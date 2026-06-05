package com.cnmaps

/**
 * Process-wide record of whether the host app has declared privacy compliance
 * (via the `setPrivacyConsent` JS API → [RNMapsModule]). The map view checks
 * this before creating the AMap surface; the library never auto-agrees.
 */
internal object MapsPrivacy {
  @Volatile
  var consented: Boolean = false
}
