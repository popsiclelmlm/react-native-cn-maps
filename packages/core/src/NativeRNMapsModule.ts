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
// present yet (e.g. an iOS build predating this module) the JS facade degrades to
// a warning instead of throwing at import time.
export default TurboModuleRegistry.get<Spec>('RNMapsModule');
