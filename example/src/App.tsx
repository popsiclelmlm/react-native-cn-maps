import { useCallback, useRef, useState } from 'react';
import {
  Image,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  View,
} from 'react-native';
import MapView, {
  Callout,
  Circle,
  Geojson,
  Marker,
  Overlay,
  Polygon,
  Polyline,
  UrlTile,
  setPrivacyConsent,
} from 'react-native-cn-maps';
import type {
  Camera,
  LatLng,
  MapMarkerHandle,
  MapType,
  MapViewHandle,
  Region,
} from 'react-native-cn-maps';

// Demo only: pretend the user has already accepted the privacy policy so the
// map SDK can initialize. Called at module load — before any <MapView> mounts.
// A real app MUST show its privacy policy and call this only after the user
// actually agrees.
setPrivacyConsent({ agreed: true, contains: true, shown: true });

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

// M3 marker gallery: one of each marker flavor (default / colored / image /
// custom React view / draggable) plus ref-command targets.
const DEFAULT_PIN: LatLng = { latitude: 31.2204, longitude: 121.46 };
const IMAGE_MARKER: LatLng = { latitude: 31.235, longitude: 121.468 };
const CUSTOM_MARKER: LatLng = { latitude: 31.2246, longitude: 121.49 };
const DRAGGABLE_MARKER: LatLng = { latitude: 31.218, longitude: 121.478 };
const ANIMATE_TARGET: LatLng = { latitude: 31.232, longitude: 121.452 };

const TINY_LOGO = 'https://reactnative.dev/img/tiny_logo.png';

// M5 overlays: a line, a filled polygon fence, and a radius circle.
const LINE: LatLng[] = [
  { latitude: 31.2397, longitude: 121.499 },
  { latitude: 31.2286, longitude: 121.4753 },
  { latitude: 31.2204, longitude: 121.46 },
];
const FENCE: LatLng[] = [
  { latitude: 31.245, longitude: 121.47 },
  { latitude: 31.245, longitude: 121.49 },
  { latitude: 31.232, longitude: 121.49 },
  { latitude: 31.232, longitude: 121.47 },
];
const CIRCLE_CENTER: LatLng = { latitude: 31.2286, longitude: 121.4753 };

// Sample GeoJSON (coordinates are [lng, lat], WGS-84 per spec) — a point, a line
// and a polygon around Shanghai for the M14 Geojson demo.
const SAMPLE_GEOJSON = {
  type: 'FeatureCollection',
  features: [
    {
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [121.5, 31.25] },
    },
    {
      type: 'Feature',
      geometry: {
        type: 'LineString',
        coordinates: [
          [121.46, 31.21],
          [121.5, 31.24],
          [121.52, 31.2],
        ],
      },
    },
    {
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [
          [
            [121.44, 31.25],
            [121.47, 31.26],
            [121.47, 31.23],
            [121.44, 31.23],
            [121.44, 31.25],
          ],
        ],
      },
    },
  ],
};

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
  const customMarkerRef = useRef<MapMarkerHandle>(null);
  const draggableMarkerRef = useRef<MapMarkerHandle>(null);

  const [mapType, setMapType] = useState<MapType>('standard');
  const [dark, setDark] = useState(false);
  const [camera, setCamera] = useState<Camera | undefined>(undefined);
  const [showTiles, setShowTiles] = useState(false);
  const [showOverlay, setShowOverlay] = useState(false);
  const [showGeojson, setShowGeojson] = useState(false);
  const [gradientLine, setGradientLine] = useState(false);
  const [snapshotUri, setSnapshotUri] = useState<string | null>(null);
  const [flags, setFlags] = useState(INITIAL_FLAGS);
  const [log, setLog] = useState<string[]>([]);
  const [pan, setPan] = useState('onPanDrag —');
  const [regionText, setRegionText] = useState('region —');
  // Bumping this re-renders the custom marker's content; with tracksViewChanges
  // on, the marker re-rasterizes to reflect it.
  const [customLabel, setCustomLabel] = useState(0);

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

  const captureSnapshot = useCallback(async () => {
    try {
      const uri = await mapRef.current?.takeSnapshot?.({ result: 'file' });
      setSnapshotUri(uri ?? null);
      pushLog(`takeSnapshot → ${uri ? 'ok' : 'empty'}`);
    } catch (e) {
      pushLog(`takeSnapshot error: ${String(e)}`);
    }
  }, [pushLog]);

  const limitToShanghai = useCallback(() => {
    mapRef.current?.setMapBoundaries?.(
      { latitude: 31.27, longitude: 121.52 },
      { latitude: 31.19, longitude: 121.43 }
    );
    pushLog('setMapBoundaries → Shanghai box');
  }, [pushLog]);

  const logMarkerFrames = useCallback(async () => {
    try {
      const frames = await mapRef.current?.getMarkersFrames?.();
      pushLog(`getMarkersFrames → ${Object.keys(frames ?? {}).join(', ')}`);
    } catch (e) {
      pushLog(`getMarkersFrames error: ${String(e)}`);
    }
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
        onPress={(e) =>
          pushLog(`onPress ${coordText(e.nativeEvent.coordinate)}`)
        }
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
        >
          {/* Custom <Callout> (M4): green pin + tappable custom bubble. */}
          <Callout onPress={() => pushLog('callout onPress bund')}>
            <View style={styles.callout}>
              <Text style={styles.calloutTitle}>The Bund 外滩</Text>
              <Text style={styles.calloutBody}>Custom callout — tap me</Text>
            </View>
          </Callout>
        </Marker>
        <Marker
          coordinate={PEOPLES_SQUARE}
          identifier="square"
          title="People's Square"
          description="人民广场"
          pinColor="purple"
          onPress={(e) => pushLog(`marker onPress ${e.nativeEvent.identifier}`)}
        />

        {/* Default pin (no pinColor / image). */}
        <Marker
          coordinate={DEFAULT_PIN}
          identifier="default"
          title="Default pin"
          onPress={(e) => pushLog(`marker onPress ${e.nativeEvent.identifier}`)}
        />

        {/* Image marker resolved from a remote uri. */}
        <Marker
          coordinate={IMAGE_MARKER}
          identifier="image"
          title="Image marker"
          image={{ uri: TINY_LOGO }}
          onPress={(e) => pushLog(`marker onPress ${e.nativeEvent.identifier}`)}
        />

        {/* Custom React content rasterized into the icon; ref drives commands. */}
        <Marker
          ref={customMarkerRef}
          coordinate={CUSTOM_MARKER}
          identifier="custom"
          title="Custom view"
          tracksViewChanges
          onSelect={(e) =>
            pushLog(`marker onSelect ${e.nativeEvent.identifier}`)
          }
          onCalloutPress={() => pushLog('marker onCalloutPress custom')}
        >
          <View style={styles.customMarker}>
            <Text style={styles.customMarkerText}>🚇 {customLabel}</Text>
          </View>
        </Marker>

        {/* Draggable marker; drag + animate-command target. */}
        <Marker
          ref={draggableMarkerRef}
          coordinate={DRAGGABLE_MARKER}
          identifier="draggable"
          title="Drag me"
          pinColor="#1f6feb"
          draggable
          onDragStart={(e) =>
            pushLog(`marker onDragStart ${coordText(e.nativeEvent.coordinate)}`)
          }
          onDragEnd={(e) =>
            pushLog(`marker onDragEnd ${coordText(e.nativeEvent.coordinate)}`)
          }
        />

        {/* M5 overlays. */}
        <Polyline
          coordinates={LINE}
          strokeColor="#e2231a"
          strokeColors={
            gradientLine ? ['#ff0000', '#00ff00', '#0000ff'] : undefined
          }
          strokeWidth={4}
          lineCap="round"
          lineJoin="round"
          tappable
          onPress={() => pushLog('polyline onPress')}
        />
        <Polygon
          coordinates={FENCE}
          strokeColor="#1f6feb"
          strokeWidth={2}
          fillColor="rgba(31,111,235,0.2)"
        />
        <Circle
          center={CIRCLE_CENTER}
          radius={800}
          strokeColor="#2e7d32"
          strokeWidth={2}
          fillColor="rgba(46,125,50,0.15)"
        />
        {showTiles && (
          <UrlTile
            urlTemplate="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
            maximumZ={19}
            zIndex={-1}
          />
        )}
        {showOverlay && (
          <Overlay
            image={{ uri: 'https://reactnative.dev/img/tiny_logo.png' }}
            bounds={[
              { latitude: 31.27, longitude: 121.44 },
              { latitude: 31.19, longitude: 121.51 },
            ]}
            opacity={0.7}
          />
        )}
        {showGeojson && (
          <Geojson
            geojson={SAMPLE_GEOJSON}
            strokeColor="#8e24aa"
            strokeWidth={3}
            fillColor="rgba(142,36,170,0.2)"
            pinColor="purple"
          />
        )}
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

      <ScrollView
        style={styles.panel}
        contentContainerStyle={styles.panelInner}
      >
        <Text style={styles.sectionTitle}>Camera / region</Text>
        <View style={styles.buttonRow}>
          <Pressable style={styles.button} onPress={flyToBeijing}>
            <Text style={styles.buttonText}>Fly to Beijing (camera)</Text>
          </Pressable>
          <Pressable style={styles.button} onPress={backToShanghai}>
            <Text style={styles.buttonText}>Back to Shanghai (animate)</Text>
          </Pressable>
        </View>

        <Text style={styles.sectionTitle}>Snapshot (M13)</Text>
        <View style={styles.buttonRow}>
          <Pressable style={styles.button} onPress={captureSnapshot}>
            <Text style={styles.buttonText}>takeSnapshot</Text>
          </Pressable>
        </View>
        {snapshotUri && (
          <Image source={{ uri: snapshotUri }} style={styles.snapshot} />
        )}

        <Text style={styles.sectionTitle}>Commands (M15)</Text>
        <View style={styles.buttonRow}>
          <Pressable style={styles.button} onPress={limitToShanghai}>
            <Text style={styles.buttonText}>setMapBoundaries</Text>
          </Pressable>
          <Pressable style={styles.button} onPress={logMarkerFrames}>
            <Text style={styles.buttonText}>getMarkersFrames</Text>
          </Pressable>
        </View>

        <Text style={styles.sectionTitle}>Markers (M3)</Text>
        <View style={styles.buttonRow}>
          <Pressable
            style={styles.button}
            onPress={() => customMarkerRef.current?.showCallout()}
          >
            <Text style={styles.buttonText}>Show callout (custom)</Text>
          </Pressable>
          <Pressable
            style={styles.button}
            onPress={() => {
              setCustomLabel((n) => n + 1);
              pushLog('custom marker label bumped');
            }}
          >
            <Text style={styles.buttonText}>Bump custom label</Text>
          </Pressable>
          <Pressable
            style={styles.button}
            onPress={() => customMarkerRef.current?.redraw()}
          >
            <Text style={styles.buttonText}>Redraw custom</Text>
          </Pressable>
          <Pressable
            style={styles.button}
            onPress={() => {
              draggableMarkerRef.current?.animateMarkerToCoordinate(
                ANIMATE_TARGET,
                1000
              );
              pushLog('animate draggable marker');
            }}
          >
            <Text style={styles.buttonText}>Animate draggable</Text>
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

        <Text style={styles.sectionTitle}>Tiles (M11) / Overlay (M12)</Text>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>UrlTile: OSM raster overlay</Text>
          <Switch value={showTiles} onValueChange={setShowTiles} />
        </View>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>Overlay: image ground overlay</Text>
          <Switch value={showOverlay} onValueChange={setShowOverlay} />
        </View>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>
            Geojson: point + line + polygon
          </Text>
          <Switch value={showGeojson} onValueChange={setShowGeojson} />
        </View>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>Polyline: gradient (M16)</Text>
          <Switch value={gradientLine} onValueChange={setGradientLine} />
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
  snapshot: {
    width: 160,
    height: 100,
    marginTop: 8,
    borderRadius: 6,
    backgroundColor: '#eee',
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
  customMarker: {
    paddingVertical: 6,
    paddingHorizontal: 10,
    borderRadius: 14,
    backgroundColor: '#1f6feb',
    borderWidth: 2,
    borderColor: '#fff',
  },
  customMarkerText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '700',
  },
  callout: {
    padding: 8,
    backgroundColor: '#fff',
    borderRadius: 8,
    minWidth: 160,
  },
  calloutTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: '#111',
  },
  calloutBody: {
    fontSize: 12,
    color: '#555',
    marginTop: 2,
  },
});
