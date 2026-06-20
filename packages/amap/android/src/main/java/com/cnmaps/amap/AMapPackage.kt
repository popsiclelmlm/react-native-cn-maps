package com.cnmaps.amap

import com.cnmaps.adapter.CnMapAdapterRegistry
import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager

/**
 * Provider package for AMap. Autolink instantiates it, which registers the AMap
 * factory with the core registry — that is the package's entire job. All view
 * managers and modules live in the core package; this contributes none.
 */
class AMapPackage : BaseReactPackage() {
  init {
    CnMapAdapterRegistry.register(AMapAdapterFactory)
  }

  override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> =
    emptyList()

  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? = null

  override fun getReactModuleInfoProvider() = ReactModuleInfoProvider { emptyMap() }
}
