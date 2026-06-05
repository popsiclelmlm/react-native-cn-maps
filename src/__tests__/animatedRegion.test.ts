import { describe, expect, it } from '@jest/globals';
import { AnimatedRegion } from '../AnimatedRegion';

describe('AnimatedRegion', () => {
  it('initializes from a region and exposes a toJSON snapshot', () => {
    const region = new AnimatedRegion({
      latitude: 1,
      longitude: 2,
      latitudeDelta: 3,
      longitudeDelta: 4,
    });
    expect(region.toJSON()).toEqual({
      latitude: 1,
      longitude: 2,
      latitudeDelta: 3,
      longitudeDelta: 4,
    });
  });

  it('defaults missing fields to 0', () => {
    expect(new AnimatedRegion().toJSON()).toEqual({
      latitude: 0,
      longitude: 0,
      latitudeDelta: 0,
      longitudeDelta: 0,
    });
  });

  it('setValue updates the snapshot', () => {
    const region = new AnimatedRegion();
    region.setValue({ latitude: 10, longitude: 20 });
    expect(region.toJSON()).toMatchObject({ latitude: 10, longitude: 20 });
  });

  it('timing/spring return composite animations', () => {
    const region = new AnimatedRegion();
    const timing = region.timing({
      latitude: 5,
      duration: 100,
      useNativeDriver: false,
    });
    const spring = region.spring({ latitude: 5, useNativeDriver: false });
    expect(typeof timing.start).toBe('function');
    expect(typeof spring.start).toBe('function');
  });

  it('addListener fires with a region snapshot and can be removed', () => {
    const region = new AnimatedRegion();
    let received: unknown = null;
    const id = region.addListener((r) => {
      received = r;
    });
    region.latitude.setValue(42);
    expect(received).toMatchObject({ latitude: 42 });
    region.removeListener(id);
  });
});
