package com.cnmaps.baidu

import com.cnmaps.adapter.CnMapAdapterRegistry
import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager

/**
 * Provider package for Baidu. Autolink instantiates it, which registers the Baidu
 * factory with the core registry. All view managers / modules live in the core
 * package; this contributes none.
 */
class BaiduPackage : BaseReactPackage() {
  init {
    CnMapAdapterRegistry.register(BaiduMapAdapterFactory)
  }

  override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> =
    emptyList()

  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? = null

  override fun getReactModuleInfoProvider() = ReactModuleInfoProvider { emptyMap() }
}
