package com.cnmaps

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNMapsUrlTileManagerDelegate
import com.facebook.react.viewmanagers.RNMapsUrlTileManagerInterface

@ReactModule(name = UrlTileManager.REACT_CLASS)
class UrlTileManager : SimpleViewManager<UrlTileView>(),
  RNMapsUrlTileManagerInterface<UrlTileView> {
  private val delegate: ViewManagerDelegate<UrlTileView> =
    RNMapsUrlTileManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<UrlTileView> = delegate

  override fun getName(): String = REACT_CLASS

  public override fun createViewInstance(context: ThemedReactContext): UrlTileView {
    return UrlTileView(context)
  }

  @ReactProp(name = "urlTemplate")
  override fun setUrlTemplate(view: UrlTileView, value: String?) {
    view.setUrlTemplateValue(value)
  }

  @ReactProp(name = "minimumZ", defaultInt = 0)
  override fun setMinimumZ(view: UrlTileView, value: Int) {
    view.setMinimumZValue(value)
  }

  @ReactProp(name = "maximumZ", defaultInt = 25)
  override fun setMaximumZ(view: UrlTileView, value: Int) {
    view.setMaximumZValue(value)
  }

  @ReactProp(name = "maximumNativeZ", defaultInt = 25)
  override fun setMaximumNativeZ(view: UrlTileView, value: Int) {
    // best-effort: AMap upsamples automatically; not separately controllable.
  }

  @ReactProp(name = "tileSize", defaultInt = 256)
  override fun setTileSize(view: UrlTileView, value: Int) {
    view.setTileSizeValue(value)
  }

  @ReactProp(name = "doubleTileSize", defaultBoolean = false)
  override fun setDoubleTileSize(view: UrlTileView, value: Boolean) {
    if (value) view.setTileSizeValue(512)
  }

  @ReactProp(name = "flipY", defaultBoolean = false)
  override fun setFlipY(view: UrlTileView, value: Boolean) {
    view.setFlipYValue(value)
  }

  @ReactProp(name = "opacity", defaultDouble = 1.0)
  override fun setOpacity(view: UrlTileView, value: Double) {
    // best-effort: AMap Android TileOverlay exposes no opacity API.
  }

  @ReactProp(name = "overlayZIndex", defaultDouble = 0.0)
  override fun setOverlayZIndex(view: UrlTileView, value: Double) {
    view.setZIndexValue(value.toFloat())
  }

  @ReactProp(name = "offlineMode", defaultBoolean = false)
  override fun setOfflineMode(view: UrlTileView, value: Boolean) {
    // best-effort: not separately controllable on AMap Android.
  }

  @ReactProp(name = "tileCachePath")
  override fun setTileCachePath(view: UrlTileView, value: String?) {
    view.setDiskCacheDir(value)
  }

  @ReactProp(name = "tileCacheMaxAge", defaultInt = 0)
  override fun setTileCacheMaxAge(view: UrlTileView, value: Int) {
    // best-effort: AMap disk cache age is not separately controllable.
  }

  companion object {
    const val REACT_CLASS = "RNMapsUrlTile"
  }
}
