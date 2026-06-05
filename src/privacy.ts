import NativeRNMapsModule from './NativeRNMapsModule';

export interface PrivacyConsentOptions {
  /** Whether the user agreed to the privacy policy. Defaults to `true`. */
  agreed?: boolean;
  /** Whether the app's privacy policy contains the SDK terms. Defaults to `true`. */
  contains?: boolean;
  /** Whether the privacy policy was shown to the user. Defaults to `true`. */
  shown?: boolean;
}

/**
 * Records the user's privacy-policy consent with the underlying map SDK.
 *
 * China map SDKs (AMap, etc.) will not initialize — the map renders blank —
 * until the host app declares privacy compliance. Call this **before mounting
 * any `<MapView>`**, and only after the user has actually accepted your privacy
 * policy. The library never auto-agrees on the app's behalf.
 *
 * @example
 * // after the user taps "Agree" in your privacy dialog:
 * setPrivacyConsent({ agreed: true, contains: true, shown: true });
 */
export function setPrivacyConsent(options: PrivacyConsentOptions = {}): void {
  const { agreed = true, contains = true, shown = true } = options;

  if (NativeRNMapsModule == null) {
    if (__DEV__) {
      console.warn(
        '[react-native-cn-maps] setPrivacyConsent: the native RNMapsModule is ' +
          'unavailable on this platform/build. Rebuild the native app after ' +
          'upgrading. The map will not render until consent is recorded.'
      );
    }
    return;
  }

  NativeRNMapsModule.setPrivacyConsent(agreed, contains, shown);
}
