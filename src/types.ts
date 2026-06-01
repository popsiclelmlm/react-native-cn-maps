import type { ReactNode } from 'react';
import type { ColorValue, ViewProps } from 'react-native';

export type MapProvider = 'amap' | 'baidu' | 'tencent';

export type CoordinateSystem = 'gcj02' | 'wgs84';

export type LatLng = {
  latitude: number;
  longitude: number;
};

export type Region = LatLng & {
  latitudeDelta: number;
  longitudeDelta: number;
};

export type MapEvent<T = Record<string, unknown>> = {
  nativeEvent: T;
};

export type RegionChangeEvent = MapEvent<{
  region: Region;
  isGesture?: boolean;
}>;

export type MarkerPressEvent = MapEvent<{
  coordinate: LatLng;
  identifier: string;
}>;

export type MapViewProps = ViewProps & {
  provider?: MapProvider;
  coordinateSystem?: CoordinateSystem;
  initialRegion?: Region;
  region?: Region;
  showsUserLocation?: boolean;
  zoomEnabled?: boolean;
  scrollEnabled?: boolean;
  rotateEnabled?: boolean;
  pitchEnabled?: boolean;
  children?: ReactNode;
  onRegionChange?: (event: RegionChangeEvent) => void;
  onRegionChangeComplete?: (event: RegionChangeEvent) => void;
};

export type MarkerProps = ViewProps & {
  coordinate: LatLng;
  identifier?: string;
  title?: string;
  description?: string;
  pinColor?: ColorValue;
  draggable?: boolean;
  onPress?: (event: MarkerPressEvent) => void;
};

export type MapViewHandle = {
  animateToRegion: (region: Region, duration?: number) => void;
};
