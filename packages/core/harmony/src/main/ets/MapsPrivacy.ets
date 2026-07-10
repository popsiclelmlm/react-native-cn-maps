/*
 * Process-wide record of whether the host app has declared privacy compliance (via
 * the `setPrivacyConsent` JS API → RNMapsModuleTurbo). The map view checks this
 * before creating the provider surface; the library never auto-agrees.
 *
 * ArkTS port of core/android `MapsPrivacy.kt`.
 */
class Privacy {
  consented: boolean = false;
}

export const MapsPrivacy = new Privacy();
