/*
 * L1 unit tests for the provider registry selection logic — no map SDK, no device.
 * Uses a fake factory whose create()/mapBuilder() are never invoked (they throw),
 * so the test needs no real adapter nor ArkUI context.
 */
import { describe, it, expect } from '@ohos/hypium';
import common from '@ohos.app.ability.common';
import { Registry } from '../main/ets/adapter/CnMapAdapterRegistry';
import { CnMapAdapter, CnMapAdapterFactory, CnMapBuilder } from '../main/ets/adapter/CnMapAdapter';

class FakeFactory implements CnMapAdapterFactory {
  readonly providerName: string;

  constructor(name: string) {
    this.providerName = name;
  }

  create(context: common.Context): CnMapAdapter {
    throw new Error('create() not used in registry tests');
  }

  mapBuilder(): CnMapBuilder {
    throw new Error('mapBuilder() not used in registry tests');
  }

  applyPrivacyConsent(context: common.Context, agreed: boolean, contains: boolean, shown: boolean): void {
  }
}

export default function registryTest() {
  describe('CnMapAdapterRegistry', () => {
    it('register dedupes by providerName and reports hasAdapter', 0, () => {
      const r = new Registry();
      expect(r.hasAdapter()).assertFalse();
      r.register(new FakeFactory('amap'));
      r.register(new FakeFactory('amap')); // duplicate name ignored
      r.register(new FakeFactory('baidu'));
      expect(r.hasAdapter()).assertTrue();
      expect(r.factoryFor('amap')?.providerName).assertEqual('amap');
      expect(r.factoryFor('baidu')?.providerName).assertEqual('baidu');
    });

    it('factoryFor falls back to first-registered for blank/unknown', 0, () => {
      const r = new Registry();
      r.register(new FakeFactory('amap'));
      r.register(new FakeFactory('baidu'));
      expect(r.factoryFor(null)?.providerName).assertEqual('amap');
      expect(r.factoryFor('')?.providerName).assertEqual('amap');
      expect(r.factoryFor('tencent')?.providerName).assertEqual('amap'); // unknown → first
    });

    it('factoryFor returns null when nothing is registered', 0, () => {
      const r = new Registry();
      expect(r.factoryFor('amap')).assertNull();
    });
  });
}
