/*
 * RNOH package for react-native-cn-maps (core). Contributes the privacy TurboModule
 * (`RNMapsModule`). The `RNMapsMapView` Fabric component is an ArkUI custom
 * component (CnMapHostComponent) the host app renders from its custom-component
 * builder — see example/harmony and the integration guide.
 *
 * Mirrors the role of core/android `MapsPackage.kt`. Provider packages
 * (AMapPackage, ...) are separate RNPackages that only self-register their adapter
 * factory; this core package carries zero provider references.
 *
 * 查证: RNPackage / TurboModulesFactory / TurboModuleContext base classes + import
 * path for the pinned RNOH 0.72 line.
 */
import {
  RNPackage, TurboModulesFactory, TurboModule, TurboModuleContext
} from '@rnoh/react-native-openharmony/ts';
import { RNMapsModuleTurbo } from './RNMapsModuleTurbo';

class CnMapsTurboModulesFactory extends TurboModulesFactory {
  createTurboModule(name: string): TurboModule | null {
    if (name === RNMapsModuleTurbo.NAME) {
      return new RNMapsModuleTurbo(this.ctx);
    }
    return null;
  }

  hasTurboModule(name: string): boolean {
    return name === RNMapsModuleTurbo.NAME;
  }
}

export class CnMapsPackage extends RNPackage {
  createTurboModulesFactory(ctx: TurboModuleContext): TurboModulesFactory {
    return new CnMapsTurboModulesFactory(ctx);
  }
}
