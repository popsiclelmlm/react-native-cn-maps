/*
 * Public entry of the Tencent provider HAR (rn-cn-maps-tencent). The host app
 * registers `TencentPackage` in its RNPackagesFactory; that registration
 * self-registers the Tencent adapter factory with the core registry.
 */
export { TencentPackage, TencentMapAdapterFactory, TencentMapAdapter } from './src/main/ets/TencentMapAdapter';
