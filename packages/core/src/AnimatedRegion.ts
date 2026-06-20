import { Animated, Easing } from 'react-native';
import type { Region } from './types';

type RegionInput = Partial<Region>;

type TimingConfig = RegionInput & {
  duration?: number;
  easing?: (value: number) => number;
  delay?: number;
  isInteraction?: boolean;
  useNativeDriver: boolean;
};

type SpringConfig = RegionInput & {
  overshootClamping?: boolean;
  restDisplacementThreshold?: number;
  restSpeedThreshold?: number;
  velocity?: number;
  bounciness?: number;
  speed?: number;
  tension?: number;
  friction?: number;
  stiffness?: number;
  damping?: number;
  mass?: number;
  delay?: number;
  isInteraction?: boolean;
  useNativeDriver: boolean;
};

type DecayConfig = RegionInput & {
  velocity?: number;
  deceleration?: number;
  isInteraction?: boolean;
  useNativeDriver: boolean;
};

const REGION_KEYS = [
  'latitude',
  'longitude',
  'latitudeDelta',
  'longitudeDelta',
] as const;

type RegionKey = (typeof REGION_KEYS)[number];

/**
 * RNM-compatible `AnimatedRegion` — a wrapper around four `Animated.Value`s
 * exposing the same surface area as `react-native-maps`. The class itself
 * drives the native map imperatively (degraded to per-frame `animateToRegion`,
 * coalesced via rAF) so the values can animate the map without a native driver.
 * `addListener` fires with a synthesized `Region` snapshot.
 */
export class AnimatedRegion {
  latitude: Animated.Value;
  longitude: Animated.Value;
  latitudeDelta: Animated.Value;
  longitudeDelta: Animated.Value;

  private _listeners: Record<
    string,
    {
      callback: (region: Region) => void;
      tokens: Record<RegionKey, string>;
    }
  > = {};
  private _listenerCounter = 0;

  constructor(valueIn?: RegionInput) {
    this.latitude = new Animated.Value(valueIn?.latitude ?? 0);
    this.longitude = new Animated.Value(valueIn?.longitude ?? 0);
    this.latitudeDelta = new Animated.Value(valueIn?.latitudeDelta ?? 0);
    this.longitudeDelta = new Animated.Value(valueIn?.longitudeDelta ?? 0);
  }

  setValue(value: RegionInput) {
    if (value.latitude !== undefined) {
      this.latitude.setValue(value.latitude);
    }
    if (value.longitude !== undefined) {
      this.longitude.setValue(value.longitude);
    }
    if (value.latitudeDelta !== undefined) {
      this.latitudeDelta.setValue(value.latitudeDelta);
    }
    if (value.longitudeDelta !== undefined) {
      this.longitudeDelta.setValue(value.longitudeDelta);
    }
  }

  setOffset(offset: RegionInput) {
    if (offset.latitude !== undefined) {
      this.latitude.setOffset(offset.latitude);
    }
    if (offset.longitude !== undefined) {
      this.longitude.setOffset(offset.longitude);
    }
    if (offset.latitudeDelta !== undefined) {
      this.latitudeDelta.setOffset(offset.latitudeDelta);
    }
    if (offset.longitudeDelta !== undefined) {
      this.longitudeDelta.setOffset(offset.longitudeDelta);
    }
  }

  flattenOffset() {
    this.latitude.flattenOffset();
    this.longitude.flattenOffset();
    this.latitudeDelta.flattenOffset();
    this.longitudeDelta.flattenOffset();
  }

  stopAnimation(callback?: (region: Region) => void) {
    this.latitude.stopAnimation();
    this.longitude.stopAnimation();
    this.latitudeDelta.stopAnimation();
    this.longitudeDelta.stopAnimation();
    callback?.(this.__getValue());
  }

  addListener(callback: (region: Region) => void): string {
    const id = String(++this._listenerCounter);
    const fire = () => callback(this.__getValue());
    this._listeners[id] = {
      callback,
      tokens: {
        latitude: this.latitude.addListener(fire),
        longitude: this.longitude.addListener(fire),
        latitudeDelta: this.latitudeDelta.addListener(fire),
        longitudeDelta: this.longitudeDelta.addListener(fire),
      },
    };
    return id;
  }

  removeListener(id: string) {
    const listener = this._listeners[id];
    if (!listener) {
      return;
    }
    this.latitude.removeListener(listener.tokens.latitude);
    this.longitude.removeListener(listener.tokens.longitude);
    this.latitudeDelta.removeListener(listener.tokens.latitudeDelta);
    this.longitudeDelta.removeListener(listener.tokens.longitudeDelta);
    delete this._listeners[id];
  }

  removeAllListeners() {
    Object.keys(this._listeners).forEach((id) => this.removeListener(id));
    this.latitude.removeAllListeners();
    this.longitude.removeAllListeners();
    this.latitudeDelta.removeAllListeners();
    this.longitudeDelta.removeAllListeners();
  }

  spring(config: SpringConfig): Animated.CompositeAnimation {
    const { useNativeDriver, ...rest } = config;
    return Animated.parallel(
      REGION_KEYS.filter((key) => config[key] !== undefined).map((key) =>
        Animated.spring(this[key], {
          ...rest,
          toValue: config[key] as number,
          useNativeDriver,
        })
      )
    );
  }

  timing(config: TimingConfig): Animated.CompositeAnimation {
    const { useNativeDriver, easing, duration, delay, ...rest } = config;
    return Animated.parallel(
      REGION_KEYS.filter((key) => config[key] !== undefined).map((key) =>
        Animated.timing(this[key], {
          ...rest,
          toValue: config[key] as number,
          duration: duration ?? 500,
          easing: easing ?? Easing.inOut(Easing.ease),
          delay,
          useNativeDriver,
        })
      )
    );
  }

  decay(config: DecayConfig): Animated.CompositeAnimation {
    const { useNativeDriver, velocity, deceleration, isInteraction } = config;
    return Animated.parallel(
      REGION_KEYS.filter((key) => config[key] !== undefined).map((key) =>
        Animated.decay(this[key], {
          velocity: velocity ?? 0,
          deceleration,
          isInteraction,
          useNativeDriver,
        })
      )
    );
  }

  __getValue(): Region {
    // `Animated.Value` doesn't expose a public getter, but its private
    // `_value` is the established RNM-internal way to read the current
    // snapshot. Include `_offset` too so the snapshot stays correct after
    // `setOffset` (RN's own `__getValue` is `_value + _offset`). Cast through
    // unknown to avoid the `any` lint.
    const read = (v: Animated.Value) => {
      const internal = v as unknown as { _value: number; _offset?: number };
      return internal._value + (internal._offset ?? 0);
    };
    return {
      latitude: read(this.latitude),
      longitude: read(this.longitude),
      latitudeDelta: read(this.latitudeDelta),
      longitudeDelta: read(this.longitudeDelta),
    };
  }

  __getAnimatedValue() {
    return this.__getValue();
  }

  /** RNM parity: a plain {@link Region} snapshot of the current values. */
  toJSON(): Region {
    return this.__getValue();
  }
}

export default AnimatedRegion;
