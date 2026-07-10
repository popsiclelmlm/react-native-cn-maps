/*
 * Public entry of the Huawei Map Kit provider HAR (rn-cn-maps-mapkit). The host app
 * registers `MapKitPackage` in its RNPackagesFactory; that registration
 * self-registers the Map Kit adapter factory with the core registry.
 *
 * 华为 Map Kit 是鸿蒙系统自带地图（`@kit.MapKit`），仅鸿蒙端存在。
 */
export { MapKitPackage, MapKitMapAdapterFactory, MapKitAdapter } from './src/main/ets/MapKitAdapter';
