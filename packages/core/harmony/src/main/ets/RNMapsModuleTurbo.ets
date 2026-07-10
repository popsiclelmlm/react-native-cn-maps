/*
 * TurboModule backing the `setPrivacyConsent` JS API (core JS
 * `src/NativeRNMapsModule.ts`). Records consent in the core MapsPrivacy flag and
 * fans the declaration out to every registered provider factory (the AMap factory
 * forwards it to MapsInitializer, which otherwise refuses to initialize → blank
 * map). Must be invoked before any `<MapView>` mounts.
 *
 * ArkTS port of core/android `RNMapsModule.kt`.
 *
 * 查证: TurboModule base class + import path for the pinned RNOH 0.72 line. Once
 * `codegen-harmony` generates the spec base, extend the generated
 * `RNMapsModule`-spec class instead of the bare TurboModule.
 */
import { TurboModule } from '@rnoh/react-native-openharmony/ts';
import { CnMapAdapterRegistry } from './adapter/CnMapAdapterRegistry';
import { MapsPrivacy } from './MapsPrivacy';

export class RNMapsModuleTurbo extends TurboModule {
  static readonly NAME: string = 'RNMapsModule';

  setPrivacyConsent(agreed: boolean, contains: boolean, shown: boolean): void {
    MapsPrivacy.consented = agreed;
    CnMapAdapterRegistry.applyPrivacyConsent(this.ctx.uiAbilityContext, agreed, contains, shown);
  }
}
