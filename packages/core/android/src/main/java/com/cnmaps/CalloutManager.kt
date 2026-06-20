package com.cnmaps

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNMapsCalloutManagerDelegate
import com.facebook.react.viewmanagers.RNMapsCalloutManagerInterface

@ReactModule(name = CalloutManager.REACT_CLASS)
class CalloutManager : ViewGroupManager<CalloutView>(),
  RNMapsCalloutManagerInterface<CalloutView> {
  private val delegate: ViewManagerDelegate<CalloutView> =
    RNMapsCalloutManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<CalloutView> = delegate

  override fun getName(): String = REACT_CLASS

  public override fun createViewInstance(context: ThemedReactContext): CalloutView {
    return CalloutView(context)
  }

  @ReactProp(name = "tooltip", defaultBoolean = false)
  override fun setTooltip(view: CalloutView, value: Boolean) {
    view.tooltip = value
  }

  companion object {
    const val REACT_CLASS = "RNMapsCallout"
  }
}
