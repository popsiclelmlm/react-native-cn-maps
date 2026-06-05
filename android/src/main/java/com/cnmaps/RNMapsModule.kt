package com.cnmaps

import com.amap.api.maps.MapsInitializer
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule

/**
 * TurboModule backing the `setPrivacyConsent` JS API. Forwards the host app's
 * privacy-compliance declaration to the AMap SDK, which otherwise refuses to
 * initialize (errorCode 555570 → blank map). Must be invoked before any
 * `<MapView>` mounts.
 */
@ReactModule(name = RNMapsModule.NAME)
class RNMapsModule(reactContext: ReactApplicationContext) :
  NativeRNMapsModuleSpec(reactContext) {

  override fun getName(): String = NAME

  override fun setPrivacyConsent(agreed: Boolean, contains: Boolean, shown: Boolean) {
    val app = reactApplicationContext.applicationContext
    // AMap: updatePrivacyShow(context, isContains, isShow)
    MapsInitializer.updatePrivacyShow(app, contains, shown)
    MapsInitializer.updatePrivacyAgree(app, agreed)
    MapsPrivacy.consented = agreed
  }

  companion object {
    const val NAME = "RNMapsModule"
  }
}
