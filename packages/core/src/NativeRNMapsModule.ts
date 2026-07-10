import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  /**
   * Records the user's privacy-policy consent with the underlying map SDK.
   *
   * AMap (and other China map SDKs) refuse to initialize until the host app
   * declares privacy compliance; without it the map renders blank. This MUST be
   * called before any `<MapView>` mounts.
   *
   * @param agreed   whether the user agreed to the privacy policy
   * @param contains whether the app's privacy policy contains the SDK's terms
   * @param shown    whether the privacy policy was shown to the user
   */
  setPrivacyConsent(agreed: boolean, contains: boolean, shown: boolean): void;
}

// `get` (not `getEnforcing`): on platforms/builds where the native module is not
// present yet (e.g. an iOS build predating this module, or RNOH/HarmonyOS before
// the C++ side registers it) the JS facade degrades to a warning instead of
// throwing at import time. RNOH 的 `get` 在 C++ 侧缺该模块时会抛异常（core RN 返回
// null），用 try/catch 守护，保持「可空」契约，避免在 bundle 顶层求值时中断注册。
let nativeRNMapsModule: Spec | null = null;
try {
  nativeRNMapsModule = TurboModuleRegistry.get<Spec>('RNMapsModule') ?? null;
} catch {
  nativeRNMapsModule = null;
}
export default nativeRNMapsModule;
