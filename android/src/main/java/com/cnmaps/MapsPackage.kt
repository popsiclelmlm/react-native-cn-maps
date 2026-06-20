package com.cnmaps

import com.cnmaps.adapter.CnMapAdapterRegistry
import com.cnmaps.amap.AMapAdapterFactory
import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager

class MapsPackage : BaseReactPackage() {
  init {
    // M1: register the bundled AMap provider. M2 relocates this into the amap
    // package's own ReactPackage, so core no longer references the provider.
    CnMapAdapterRegistry.register(AMapAdapterFactory)
  }

  override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
    return listOf(
      MapViewManager(),
      MarkerManager(),
      CalloutManager(),
      PolylineManager(),
      PolygonManager(),
      CircleManager(),
      UrlTileManager(),
      LocalTileManager(),
      OverlayManager(),
      HeatmapManager()
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
