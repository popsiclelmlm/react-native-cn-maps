/*
 * Public entry of the AMap provider HAR (rn-cn-maps-amap). The host app registers
 * `AMapPackage` in its RNPackagesFactory; that registration self-registers the AMap
 * adapter factory with the core registry.
 */
export { AMapPackage, AMapAdapterFactory } from './src/main/ets/AMapPackage';
export { AMapAdapter } from './src/main/ets/AMapAdapter';
