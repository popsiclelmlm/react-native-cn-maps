package com.cnmaps

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNMapsLocalTileManagerDelegate
import com.facebook.react.viewmanagers.RNMapsLocalTileManagerInterface

@ReactModule(name = LocalTileManager.REACT_CLASS)
class LocalTileManager : SimpleViewManager<LocalTileView>(),
  RNMapsLocalTileManagerInterface<LocalTileView> {
  private val delegate: ViewManagerDelegate<LocalTileView> =
    RNMapsLocalTileManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<LocalTileView> = delegate

  override fun getName(): String = REACT_CLASS

  public override fun createViewInstance(context: ThemedReactContext): LocalTileView {
    return LocalTileView(context)
  }

  @ReactProp(name = "pathTemplate")
  override fun setPathTemplate(view: LocalTileView, value: String?) {
    view.setPathTemplateValue(value)
  }

  @ReactProp(name = "tileSize", defaultInt = 256)
  override fun setTileSize(view: LocalTileView, value: Int) {
    view.setTileSizeValue(value)
  }

  @ReactProp(name = "useAssets", defaultBoolean = false)
  override fun setUseAssets(view: LocalTileView, value: Boolean) {
    view.setUseAssetsValue(value)
  }

  @ReactProp(name = "overlayZIndex", defaultDouble = 0.0)
  override fun setOverlayZIndex(view: LocalTileView, value: Double) {
    view.setZIndexValue(value.toFloat())
  }

  companion object {
    const val REACT_CLASS = "RNMapsLocalTile"
  }
}
