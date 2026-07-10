/*
 * Public entry of the Baidu provider HAR (rn-cn-maps-baidu). The host app registers
 * `BaiduPackage` in its RNPackagesFactory; that registration self-registers the
 * Baidu adapter factory with the core registry.
 */
export { BaiduPackage, BaiduMapAdapterFactory, BaiduMapAdapter } from './src/main/ets/BaiduMapAdapter';
