# react-native-cn-maps

Provider-agnostic core of **react-native-cn-maps** — `react-native-maps`-compatible
map components for China. This package contains the JS facade (`MapView`, `Marker`,
`Polyline`, …), all Fabric components, coordinate conversion, and the host/adapter
contract. It contains **no map SDK**; a provider package supplies the actual map.

## Install

```sh
yarn add react-native-cn-maps react-native-cn-maps-amap   # core + a provider
```

Pick a provider with the `provider` prop (`amap` / `baidu` / `tencent`) — see the
repo README's [Providers](https://github.com/popsiclelmlm/react-native-cn-maps#-providers-多地图厂商)
section. Install only the provider packages you use.

## Usage

```tsx
import MapView, { Marker } from 'react-native-cn-maps';

<MapView provider="amap" coordinateSystem="gcj02" style={{ flex: 1 }} initialRegion={...}>
  <Marker coordinate={{ latitude: 31.23, longitude: 121.47 }} title="Shanghai" />
</MapView>
```

> The map renders blank until you declare privacy consent via `setPrivacyConsent()`
> (fanned out to every installed provider) and configure the provider's SDK key.

See the repo root README for the full API, native setup, and privacy details.
