import { useCallback, useRef, useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  View,
} from 'react-native';
import MapView, { Marker } from 'react-native-cn-maps';
import type {
  Camera,
  LatLng,
  MapType,
  MapViewHandle,
  Region,
} from 'react-native-cn-maps';

// M2 "full prop matrix" demo: every MapView prop & event landed in M2 is wired
// up to a live control so each can be toggled and observed on a real device.

const SHANGHAI: Region = {
  latitude: 31.2304,
  longitude: 121.4737,
  latitudeDelta: 0.08,
  longitudeDelta: 0.08,
};

const BEIJING_CAMERA: Camera = {
  center: { latitude: 39.9042, longitude: 116.4074 },
  heading: 30,
  pitch: 45,
  zoom: 12,
};

const THE_BUND: LatLng = { latitude: 31.2397, longitude: 121.499 };
const PEOPLES_SQUARE: LatLng = { latitude: 31.2286, longitude: 121.4753 };

const MAP_TYPES: MapType[] = ['standard', 'satellite', 'hybrid'];

// Boolean props rendered as a switch grid, in display order.
const TOGGLE_KEYS = [
  'showsTraffic',
  'showsBuildings',
  'showsCompass',
  'showsScale',
  'showsIndoors',
  'showsPointsOfInterest',
  'showsUserLocation',
  'showsMyLocationButton',
  'zoomControlEnabled',
  'zoomEnabled',
  'scrollEnabled',
  'rotateEnabled',
  'pitchEnabled',
] as const;

type ToggleKey = (typeof TOGGLE_KEYS)[number];

const INITIAL_FLAGS: Record<ToggleKey, boolean> = {
  showsTraffic: false,
  showsBuildings: true,
  showsCompass: true,
  showsScale: true,
  showsIndoors: true,
  showsPointsOfInterest: true,
  showsUserLocation: false,
  showsMyLocationButton: true,
  zoomControlEnabled: false,
  zoomEnabled: true,
  scrollEnabled: true,
  rotateEnabled: true,
  pitchEnabled: true,
};

const fmt = (n: number) => n.toFixed(4);

const coordText = (c: LatLng) => `${fmt(c.latitude)}, ${fmt(c.longitude)}`;

export default function App() {
  const mapRef = useRef<MapViewHandle>(null);
  const panCount = useRef(0);

  const [mapType, setMapType] = useState<MapType>('standard');
  const [dark, setDark] = useState(false);
  const [camera, setCamera] = useState<Camera | undefined>(undefined);
  const [flags, setFlags] = useState(INITIAL_FLAGS);
  const [log, setLog] = useState<string[]>([]);
  const [pan, setPan] = useState('onPanDrag —');
  const [regionText, setRegionText] = useState('region —');

  const pushLog = useCallback((line: string) => {
    setLog((prev) => [line, ...prev].slice(0, 7));
  }, []);

  const setFlag = useCallback(
    (key: ToggleKey) => (value: boolean) =>
      setFlags((prev) => ({ ...prev, [key]: value })),
    []
  );

  const flyToBeijing = useCallback(() => {
    setCamera(BEIJING_CAMERA);
    pushLog('camera → Beijing');
  }, [pushLog]);

  const backToShanghai = useCallback(() => {
    // Drop the controlled camera, then drive the map imperatively (the M2
    // animateToRegion command) back to the initial region.
    setCamera(undefined);
    mapRef.current?.animateToRegion(SHANGHAI, 800);
    pushLog('animateToRegion → Shanghai');
  }, [pushLog]);

  return (
    <View style={styles.container}>
      <MapView
        ref={mapRef}
        style={styles.map}
        provider="amap"
        coordinateSystem="gcj02"
        initialRegion={SHANGHAI}
        camera={camera}
        mapType={mapType}
        userInterfaceStyle={dark ? 'dark' : 'light'}
        minZoomLevel={3}
        maxZoomLevel={19}
        showsTraffic={flags.showsTraffic}
        showsBuildings={flags.showsBuildings}
        showsCompass={flags.showsCompass}
        showsScale={flags.showsScale}
        showsIndoors={flags.showsIndoors}
        showsPointsOfInterest={flags.showsPointsOfInterest}
        showsUserLocation={flags.showsUserLocation}
        showsMyLocationButton={flags.showsMyLocationButton}
        zoomControlEnabled={flags.zoomControlEnabled}
        zoomEnabled={flags.zoomEnabled}
        scrollEnabled={flags.scrollEnabled}
        rotateEnabled={flags.rotateEnabled}
        pitchEnabled={flags.pitchEnabled}
        onMapReady={() => pushLog('onMapReady')}
        onMapLoaded={() => pushLog('onMapLoaded')}
        onPress={(e) => pushLog(`onPress ${coordText(e.nativeEvent.coordinate)}`)}
        onLongPress={(e) =>
          pushLog(`onLongPress ${coordText(e.nativeEvent.coordinate)}`)
        }
        onDoublePress={(e) =>
          pushLog(`onDoublePress ${coordText(e.nativeEvent.coordinate)}`)
        }
        onPanDrag={(e) => {
          panCount.current += 1;
          setPan(
            `onPanDrag ${coordText(e.nativeEvent.coordinate)} ×${panCount.current}`
          );
        }}
        onPoiClick={(e) =>
          pushLog(
            `onPoiClick ${e.nativeEvent.name ?? '(unnamed)'} ${coordText(
              e.nativeEvent.coordinate
            )}`
          )
        }
        onUserLocationChange={(e) => {
          const c = e.nativeEvent.coordinate;
          if (c) {
            pushLog(`onUserLocationChange ${coordText(c)}`);
          }
        }}
        onRegionChangeComplete={(e) =>
          setRegionText(
            `region ${coordText(e.nativeEvent.region)} (gesture: ${
              e.nativeEvent.isGesture ? 'yes' : 'no'
            })`
          )
        }
      >
        <Marker
          coordinate={THE_BUND}
          identifier="bund"
          title="The Bund"
          description="外滩"
          pinColor="green"
          onPress={(e) => pushLog(`marker onPress ${e.nativeEvent.identifier}`)}
        />
        <Marker
          coordinate={PEOPLES_SQUARE}
          identifier="square"
          title="People's Square"
          description="人民广场"
          pinColor="purple"
          onPress={(e) => pushLog(`marker onPress ${e.nativeEvent.identifier}`)}
        />
      </MapView>

      <View pointerEvents="none" style={styles.logOverlay}>
        <Text style={styles.logLine}>{regionText}</Text>
        <Text style={styles.logLine}>{pan}</Text>
        {log.map((line, index) => (
          <Text key={`${index}-${line}`} style={styles.logLine}>
            {line}
          </Text>
        ))}
      </View>

      <ScrollView style={styles.panel} contentContainerStyle={styles.panelInner}>
        <Text style={styles.sectionTitle}>Camera / region</Text>
        <View style={styles.buttonRow}>
          <Pressable style={styles.button} onPress={flyToBeijing}>
            <Text style={styles.buttonText}>Fly to Beijing (camera)</Text>
          </Pressable>
          <Pressable style={styles.button} onPress={backToShanghai}>
            <Text style={styles.buttonText}>Back to Shanghai (animate)</Text>
          </Pressable>
        </View>

        <Text style={styles.sectionTitle}>mapType</Text>
        <View style={styles.buttonRow}>
          {MAP_TYPES.map((type) => (
            <Pressable
              key={type}
              style={[styles.chip, mapType === type && styles.chipActive]}
              onPress={() => setMapType(type)}
            >
              <Text
                style={[
                  styles.chipText,
                  mapType === type && styles.chipTextActive,
                ]}
              >
                {type}
              </Text>
            </Pressable>
          ))}
        </View>

        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>userInterfaceStyle: dark</Text>
          <Switch value={dark} onValueChange={setDark} />
        </View>

        <Text style={styles.sectionTitle}>Display & gesture toggles</Text>
        {TOGGLE_KEYS.map((key) => (
          <View key={key} style={styles.toggleRow}>
            <Text style={styles.toggleLabel}>{key}</Text>
            <Switch value={flags[key]} onValueChange={setFlag(key)} />
          </View>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  map: {
    flex: 1,
  },
  logOverlay: {
    position: 'absolute',
    top: 48,
    left: 12,
    right: 12,
    padding: 8,
    borderRadius: 8,
    backgroundColor: 'rgba(0, 0, 0, 0.55)',
  },
  logLine: {
    color: '#fff',
    fontSize: 11,
    lineHeight: 16,
    fontFamily: 'Courier',
  },
  panel: {
    maxHeight: '42%',
    backgroundColor: '#fff',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#ccc',
  },
  panelInner: {
    padding: 12,
    paddingBottom: 32,
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: '#333',
    marginTop: 12,
    marginBottom: 6,
  },
  buttonRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  button: {
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 8,
    backgroundColor: '#1f6feb',
  },
  buttonText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  chip: {
    paddingVertical: 6,
    paddingHorizontal: 14,
    borderRadius: 16,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#1f6feb',
  },
  chipActive: {
    backgroundColor: '#1f6feb',
  },
  chipText: {
    color: '#1f6feb',
    fontSize: 12,
    fontWeight: '600',
  },
  chipTextActive: {
    color: '#fff',
  },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 4,
  },
  toggleLabel: {
    fontSize: 13,
    color: '#333',
    flexShrink: 1,
  },
});
