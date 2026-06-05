package com.cnmaps

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager

class MapsPackage : BaseReactPackage() {
  override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
    return listOf(
      MapViewManager(),
      MarkerManager(),
      CalloutManager(),
      PolylineManager(),
      PolygonManager(),
      CircleManager(),
      UrlTileManager(),
      LocalTileManager()
    )
  }

  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? =
    if (name == RNMapsModule.NAME) RNMapsModule(reactContext) else null

  override fun getReactModuleInfoProvider() = ReactModuleInfoProvider {
    mapOf(
      RNMapsModule.NAME to ReactModuleInfo(
        RNMapsModule.NAME,
        RNMapsModule.NAME,
        false, // canOverrideExistingModule
        false, // needsEagerInit
        false, // isCxxModule
        true // isTurboModule
      )
    )
  }
}
