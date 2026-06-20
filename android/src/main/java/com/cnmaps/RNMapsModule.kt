package com.cnmaps

import com.cnmaps.adapter.CnMapAdapterRegistry
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule

/**
 * TurboModule backing the `setPrivacyConsent` JS API. Records consent in the core
 * [MapsPrivacy] flag and fans the declaration out to every registered map adapter
 * (the AMap adapter forwards it to its SDK, which otherwise refuses to initialize —
 * errorCode 555570 → blank map). Must be invoked before any `<MapView>` mounts.
 */
@ReactModule(name = RNMapsModule.NAME)
class RNMapsModule(reactContext: ReactApplicationContext) :
  NativeRNMapsModuleSpec(reactContext) {

  override fun getName(): String = NAME

  override fun setPrivacyConsent(agreed: Boolean, contains: Boolean, shown: Boolean) {
    MapsPrivacy.consented = agreed
    CnMapAdapterRegistry.applyPrivacyConsent(
      reactApplicationContext.applicationContext, agreed, contains, shown
    )
  }

  companion object {
    const val NAME = "RNMapsModule"
  }
}
