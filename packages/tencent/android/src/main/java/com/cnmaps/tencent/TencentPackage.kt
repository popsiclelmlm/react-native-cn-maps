package com.cnmaps.tencent

import com.cnmaps.adapter.CnMapAdapterRegistry
import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager

/**
 * Provider package for Tencent. Autolink instantiates it, which registers the
 * Tencent factory with the core registry. View managers / modules live in core.
 */
class TencentPackage : BaseReactPackage() {
  init {
    CnMapAdapterRegistry.register(TencentMapAdapterFactory)
  }

  override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> =
    emptyList()

  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? = null

  override fun getReactModuleInfoProvider() = ReactModuleInfoProvider { emptyMap() }
}
