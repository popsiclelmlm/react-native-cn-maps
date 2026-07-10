import { StyleSheet, View, Text } from 'react-native';
import { Marker } from 'react-native-cn-maps';

// 展示型「我的位置」标记：蓝色圆点 + 白色光晕，可选朝向箭头。
// 坐标与朝向由父组件传入（不在示例里内置定位追踪与权限逻辑）。
const ANCHOR = { x: 0.5, y: 0.5 };
const MARKER_COLOR = '#4285F4';

const SIZE = 35;
const HALO_RADIUS = 6;
const ARROW_SIZE = 7;
const ARROW_DISTANCE = 6;
const HALO_SIZE = SIZE + HALO_RADIUS;
const HEADING_BOX_SIZE = HALO_SIZE + ARROW_SIZE + ARROW_DISTANCE;

function MyLocationMapMarker(props: any) {
  const { heading, coordinate, enableHack, children, ...rest } = props;
  if (!coordinate) {
    return null;
  }

  const rotate =
    typeof heading === 'number' && heading >= 0 ? `${heading}deg` : null;

  return (
    <Marker
      anchor={ANCHOR}
      style={styles.mapMarker}
      {...rest}
      coordinate={coordinate}
    >
      <View style={styles.container}>
        <View style={styles.markerHalo} />
        {rotate && (
          <View style={[styles.heading, { transform: [{ rotate }] }]}>
            <View style={styles.headingPointer} />
          </View>
        )}
        <View style={styles.marker}>
          {/* enableHack 时把朝向值写进不可见文本，强制标记重绘（tracksViewChanges 的老 hack） */}
          <Text style={styles.markerText}>{enableHack ? rotate : ''}</Text>
        </View>
      </View>
      {children}
    </Marker>
  );
}

const styles = StyleSheet.create({
  mapMarker: {
    zIndex: 1000,
  },
  // 外层容器用于避免光晕阴影被裁切
  container: {
    width: HEADING_BOX_SIZE,
    height: HEADING_BOX_SIZE,
  },
  heading: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: HEADING_BOX_SIZE,
    height: HEADING_BOX_SIZE,
    alignItems: 'center',
  },
  headingPointer: {
    width: 0,
    height: 0,
    backgroundColor: 'transparent',
    borderStyle: 'solid',
    borderTopWidth: 0,
    borderRightWidth: ARROW_SIZE * 0.75,
    borderBottomWidth: ARROW_SIZE,
    borderLeftWidth: ARROW_SIZE * 0.75,
    borderTopColor: 'transparent',
    borderRightColor: 'transparent',
    borderBottomColor: MARKER_COLOR,
    borderLeftColor: 'transparent',
  },
  markerHalo: {
    position: 'absolute',
    backgroundColor: 'white',
    top: 0,
    left: 0,
    width: HALO_SIZE,
    height: HALO_SIZE,
    borderRadius: Math.ceil(HALO_SIZE / 2),
    margin: (HEADING_BOX_SIZE - HALO_SIZE) / 2,
    shadowColor: 'black',
    shadowOpacity: 0.25,
    shadowRadius: 2,
    shadowOffset: {
      height: 0,
      width: 0,
    },
  },
  marker: {
    justifyContent: 'center',
    backgroundColor: MARKER_COLOR,
    width: SIZE,
    height: SIZE,
    borderRadius: Math.ceil(SIZE / 2),
    margin: (HEADING_BOX_SIZE - SIZE) / 2,
  },
  markerText: { width: 0, height: 0 },
});

export default MyLocationMapMarker;
