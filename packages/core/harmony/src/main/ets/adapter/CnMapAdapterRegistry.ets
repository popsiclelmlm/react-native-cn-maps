/*
 * Registry of map provider factories. A provider package self-registers its factory
 * (from its RNPackage constructor) and the host asks the registry for a map instead
 * of naming a concrete SDK class — which is what lets core carry zero provider
 * references.
 *
 * ArkTS port of core/android `adapter/CnMapAdapterRegistry.kt`. The Kotlin `object`
 * singleton becomes a class with a module-level singleton instance.
 */
import common from '@ohos.app.ability.common';
import { CnMapAdapter, CnMapAdapterFactory } from './CnMapAdapter';

// Exported so unit tests can construct an isolated instance (the app uses the
// module-level singleton below).
export class Registry {
  private factories: CnMapAdapterFactory[] = [];

  register(factory: CnMapAdapterFactory): void {
    const exists = this.factories.some((f) => f.providerName === factory.providerName);
    if (!exists) {
      this.factories.push(factory);
    }
  }

  hasAdapter(): boolean {
    return this.factories.length > 0;
  }

  // Resolve the factory whose providerName matches `provider`, falling back to the
  // default (first-registered) when `provider` is blank or unmatched.
  factoryFor(provider: string | null): CnMapAdapterFactory | null {
    if (provider !== null && provider.length > 0) {
      const match = this.factories.find((f) => f.providerName === provider);
      if (match !== undefined) {
        return match;
      }
    }
    return this.factories.length > 0 ? this.factories[0] : null;
  }

  // Create the adapter for `provider` (or the default), or null if none registered.
  createAdapter(context: common.Context, provider: string | null): CnMapAdapter | null {
    const factory = this.factoryFor(provider);
    return factory !== null ? factory.create(context) : null;
  }

  // Fan a privacy-compliance declaration out to every registered factory.
  applyPrivacyConsent(context: common.Context, agreed: boolean, contains: boolean, shown: boolean): void {
    this.factories.forEach((f) => f.applyPrivacyConsent(context, agreed, contains, shown));
  }
}

// Module-level singleton shared across the core HAR (matches the Kotlin `object`).
export const CnMapAdapterRegistry = new Registry();
