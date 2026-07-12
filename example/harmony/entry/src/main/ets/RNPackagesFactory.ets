/*
 * RNOH package registration for the HarmonyOS example app.
 *
 * This is the HarmonyOS analogue of RN CLI autolink — RNOH has no autolink, so the
 * host app explicitly lists the provider packages it wants. Registering AMapPackage
 * self-registers the AMap adapter factory with the core registry; to add Baidu
 * later, also `new BaiduPackage(ctx)` here (and depend on its HAR in oh-package).
 *
 * 查证: RNPackageContext / RNPackage types for the pinned RNOH 0.72 line.
 */
import { RNPackageContext, RNPackage } from '@rnoh/react-native-openharmony/ts';
import { CnMapsPackage } from 'rn-cn-maps';
import { AMapPackage } from 'rn-cn-maps-amap';
import { BaiduPackage } from 'rn-cn-maps-baidu';
import { TencentPackage } from 'rn-cn-maps-tencent';
import { MapKitPackage } from 'rn-cn-maps-mapkit';

export function createRNPackages(ctx: RNPackageContext): RNPackage[] {
  return [
    new CnMapsPackage(ctx),
    // Register the providers you use. Registration order = default fallback order
    // (first registered wins when `provider` is blank/unmatched). The runtime picks
    // by the `<MapView provider>` prop. All three vendors ship a HarmonyOS map SDK.
    new AMapPackage(ctx),
    new BaiduPackage(ctx),
    new TencentPackage(ctx),
    // 华为 Map Kit（鸿蒙自带地图）。鉴权走 AGC client_id（module.json5 metadata），
    // 无需 SDK Key/隐私 init。
    new MapKitPackage(ctx),
  ];
}
