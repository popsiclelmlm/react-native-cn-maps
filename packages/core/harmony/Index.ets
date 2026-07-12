/*
 * Public entry of the core HarmonyOS HAR (rn-cn-maps). Exposes:
 *  - CnMapsPackage: the RNOH package the host app registers (privacy TurboModule).
 *  - CnMapHostComponent: the ArkUI custom component the app renders for
 *    `RNMapsMapView` from its custom-component builder.
 *  - The provider-agnostic adapter contract that provider HARs (amap/baidu/tencent)
 *    implement and self-register with CnMapAdapterRegistry.
 */
export { CnMapsPackage } from './src/main/ets/CnMapsPackage';
export { RNMapsModuleTurbo } from './src/main/ets/RNMapsModuleTurbo';
export { CnMapHostComponent, CN_MAP_HOST_COMPONENT_TYPE } from './src/main/ets/host/CnMapHostComponent';
export { RN_MAPS_MAP_VIEW_TYPE } from './src/main/ets/host/RNMapsMapViewDescriptor';

export * from './src/main/ets/adapter/CnMapModels';
export { OverlayHandle } from './src/main/ets/adapter/OverlayHandle';
export { CnMapAdapter, CnMapAdapterFactory, CnMapBuilder } from './src/main/ets/adapter/CnMapAdapter';
export { CnMapAdapterDelegate } from './src/main/ets/adapter/CnMapAdapterDelegate';
export { CnMapAdapterRegistry } from './src/main/ets/adapter/CnMapAdapterRegistry';
export { MapsPrivacy } from './src/main/ets/MapsPrivacy';
export { tintedPinPixelMap, TINTED_PIN_WIDTH, TINTED_PIN_HEIGHT } from './src/main/ets/adapter/PinBitmap';
