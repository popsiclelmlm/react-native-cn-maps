import { useEffect, useRef, useState } from 'react';
import { StyleSheet, View, Dimensions, Animated } from 'react-native';

import {
  Animated as AnimatedMap,
  AnimatedRegion,
  Marker,
} from 'react-native-cn-maps';
import PanController from './PanController';
import PriceMarker from './AnimatedPriceMarker';
import { DemoHint } from './_ui';

const screen = Dimensions.get('window');

const ASPECT_RATIO = screen.width / screen.height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

const ITEM_SPACING = 10;
const ITEM_PREVIEW = 10;
const ITEM_WIDTH = screen.width - 2 * ITEM_SPACING - 2 * ITEM_PREVIEW;
const SNAP_WIDTH = ITEM_WIDTH + ITEM_SPACING;
const ITEM_PREVIEW_HEIGHT = 150;
const SCALE_END = screen.width / ITEM_WIDTH;
const BREAKPOINT1 = 246;
const BREAKPOINT2 = 350;
const ONE = new Animated.Value(1);

function getMarkerState(panX: any, panY: any, scrollY: any, i: any) {
  const xLeft = -SNAP_WIDTH * i + SNAP_WIDTH / 2;
  const xRight = -SNAP_WIDTH * i - SNAP_WIDTH / 2;
  const xPos = -SNAP_WIDTH * i;

  const isIndex = panX.interpolate({
    inputRange: [xRight - 1, xRight, xLeft, xLeft + 1],
    outputRange: [0, 1, 1, 0],
    extrapolate: 'clamp',
  });

  const isNotIndex = panX.interpolate({
    inputRange: [xRight - 1, xRight, xLeft, xLeft + 1],
    outputRange: [1, 0, 0, 1],
    extrapolate: 'clamp',
  });

  const center = panX.interpolate({
    inputRange: [xPos - 10, xPos, xPos + 10],
    outputRange: [0, 1, 0],
    extrapolate: 'clamp',
  });

  const selected = panX.interpolate({
    inputRange: [xRight, xPos, xLeft],
    outputRange: [0, 1, 0],
    extrapolate: 'clamp',
  });

  const translateY = Animated.multiply(isIndex, panY);

  const translateX = panX;

  const anim = Animated.multiply(
    isIndex,
    scrollY.interpolate({
      inputRange: [0, BREAKPOINT1],
      outputRange: [0, 1],
      extrapolate: 'clamp',
    })
  );

  const scale = Animated.add(
    ONE,
    Animated.multiply(
      isIndex,
      scrollY.interpolate({
        inputRange: [BREAKPOINT1, BREAKPOINT2],
        outputRange: [0, SCALE_END - 1],
        extrapolate: 'clamp',
      })
    )
  );

  // [0 => 1]
  let opacity = scrollY.interpolate({
    inputRange: [BREAKPOINT1, BREAKPOINT2],
    outputRange: [0, 1],
    extrapolate: 'clamp',
  });

  // 若 i === index：[0 => 0]
  // 若 i !== index：[0 => 1]
  opacity = Animated.multiply(isNotIndex, opacity);

  // 若 i === index：[1 => 1]
  // 若 i !== index：[1 => 0]
  opacity = opacity.interpolate({
    inputRange: [0, 1],
    outputRange: [1, 0],
  });

  let markerOpacity = scrollY.interpolate({
    inputRange: [0, BREAKPOINT1],
    outputRange: [0, 1],
    extrapolate: 'clamp',
  });

  markerOpacity = Animated.multiply(isNotIndex, markerOpacity).interpolate({
    inputRange: [0, 1],
    outputRange: [1, 0],
  });

  const markerScale = selected.interpolate({
    inputRange: [0, 1],
    outputRange: [1, 1.2],
  });

  return {
    translateY,
    translateX,
    scale,
    opacity,
    anim,
    center,
    selected,
    markerOpacity,
    markerScale,
  };
}

function AnimatedViews(props: any) {
  // 只创建一次的动画对象（等价于原 constructor 中一次性构建的实例）
  const initRef = useRef<any>(null);
  if (initRef.current === null) {
    const panX = new Animated.Value(0);
    const panY = new Animated.Value(0);

    const scrollY = panY.interpolate({
      inputRange: [-1, 1],
      outputRange: [1, -1],
    });

    const scrollX = panX.interpolate({
      inputRange: [-1, 1],
      outputRange: [1, -1],
    });

    const markers = [
      {
        id: 0,
        amount: 99,
        coordinate: {
          latitude: LATITUDE,
          longitude: LONGITUDE,
        },
      },
      {
        id: 1,
        amount: 199,
        coordinate: {
          latitude: LATITUDE + 0.004,
          longitude: LONGITUDE - 0.004,
        },
      },
      {
        id: 2,
        amount: 285,
        coordinate: {
          latitude: LATITUDE - 0.004,
          longitude: LONGITUDE - 0.004,
        },
      },
    ];

    const animations = markers.map((_m, i) =>
      getMarkerState(panX, panY, scrollY, i)
    );

    initRef.current = {
      panX,
      panY,
      scrollY,
      scrollX,
      animations,
      markers,
      region: new AnimatedRegion({
        latitude: LATITUDE,
        longitude: LONGITUDE,
        latitudeDelta: LATITUDE_DELTA,
        longitudeDelta: LONGITUDE_DELTA,
      }),
    };
  }
  const { panX, panY, scrollY, scrollX, animations, markers, region } =
    initRef.current;

  const [supported] = useState(false);

  const [index, setIndex] = useState(0);
  const indexRef = useRef(0);
  indexRef.current = index;

  const [canMoveHorizontal, setCanMoveHorizontal] = useState(true);
  const canMoveHorizontalRef = useRef(true);
  canMoveHorizontalRef.current = canMoveHorizontal;

  const onStartShouldSetPanResponder = (e: any) => {
    // 只有当手势起点落在视图之上时才响应移动：这里据此计算并返回 true，
    // 若返回 false，手势会被恰当地交给地图视图处理。
    const { pageY } = e.nativeEvent;
    const topOfMainWindow = ITEM_PREVIEW_HEIGHT + panY.__getValue();
    const topOfTap = screen.height - pageY;

    return topOfTap < topOfMainWindow;
  };

  const onMoveShouldSetPanResponder = (e: any) => {
    const { pageY } = e.nativeEvent;
    const topOfMainWindow = ITEM_PREVIEW_HEIGHT + panY.__getValue();
    const topOfTap = screen.height - pageY;

    return topOfTap < topOfMainWindow;
  };

  const onPanXChange = ({ value }: any) => {
    const newIndex = Math.floor((-1 * value + SNAP_WIDTH / 2) / SNAP_WIDTH);
    if (indexRef.current !== newIndex) {
      setIndex(newIndex);
    }
  };

  const onPanYChange = ({ value }: any) => {
    const shouldBeMovable = Math.abs(value) < 2;
    if (shouldBeMovable !== canMoveHorizontalRef.current) {
      setCanMoveHorizontal(shouldBeMovable);
      if (!shouldBeMovable) {
        const { coordinate } = markers[indexRef.current];
        region.stopAnimation();
        region
          .timing({
            latitude: scrollY.interpolate({
              inputRange: [0, BREAKPOINT1],
              outputRange: [
                coordinate.latitude,
                coordinate.latitude - LATITUDE_DELTA * 0.5 * 0.375,
              ],
              extrapolate: 'clamp',
            }),
            latitudeDelta: scrollY.interpolate({
              inputRange: [0, BREAKPOINT1],
              outputRange: [LATITUDE_DELTA, LATITUDE_DELTA * 0.5],
              extrapolate: 'clamp',
            }),
            longitudeDelta: scrollY.interpolate({
              inputRange: [0, BREAKPOINT1],
              outputRange: [LONGITUDE_DELTA, LONGITUDE_DELTA * 0.5],
              extrapolate: 'clamp',
            }),
            useNativeDriver: true, // 未显式传入时默认为 false
            duration: 0,
          })
          .start();
      } else {
        region.stopAnimation();
        region
          .timing({
            latitude: scrollX.interpolate({
              inputRange: markers.map((_m: any, i: any) => i * SNAP_WIDTH),
              outputRange: markers.map((m: any) => m.coordinate.latitude),
            }),
            longitude: scrollX.interpolate({
              inputRange: markers.map((_m: any, i: any) => i * SNAP_WIDTH),
              outputRange: markers.map((m: any) => m.coordinate.longitude),
            }),
            useNativeDriver: true, // 未显式传入时默认为 false
            duration: 0,
          })
          .start();
      }
    }
  };

  const onRegionChange = (/* region */) => {
    // region.setValue(region);
  };

  // 等价于 componentDidMount：只在挂载时注册监听并启动初始 region 动画
  useEffect(() => {
    panX.addListener(onPanXChange);
    panY.addListener(onPanYChange);

    region.stopAnimation();
    region
      .timing({
        latitude: scrollX.interpolate({
          inputRange: markers.map((_m: any, i: any) => i * SNAP_WIDTH),
          outputRange: markers.map((m: any) => m.coordinate.latitude),
        }),
        longitude: scrollX.interpolate({
          inputRange: markers.map((_m: any, i: any) => i * SNAP_WIDTH),
          outputRange: markers.map((m: any) => m.coordinate.longitude),
        }),
        useNativeDriver: true, // 未显式传入时默认为 false
        duration: 0,
      })
      .start();
    // 仅在挂载时注册一次监听，等价于 componentDidMount
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!supported) {
    return (
      <View style={styles.errorWrap}>
        <DemoHint>Fabric 地图暂不支持该动画</DemoHint>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <PanController
        style={styles.container}
        vertical
        horizontal={canMoveHorizontal}
        xMode="snap"
        snapSpacingX={SNAP_WIDTH}
        yBounds={[-1 * screen.height, 0]}
        xBounds={[-screen.width * (markers.length - 1), 0]}
        panY={panY}
        panX={panX}
        onStartShouldSetPanResponder={onStartShouldSetPanResponder}
        onMoveShouldSetPanResponder={onMoveShouldSetPanResponder}
      >
        <AnimatedMap
          provider={props.provider}
          style={styles.map}
          region={region}
          onRegionChange={onRegionChange}
        >
          {markers.map((marker: any, i: any) => {
            const { selected, markerOpacity, markerScale } = animations[i];

            return (
              <Marker key={marker.id} coordinate={marker.coordinate}>
                <PriceMarker
                  style={{
                    opacity: markerOpacity,
                    transform: [{ scale: markerScale }],
                  }}
                  amount={marker.amount}
                  selected={selected}
                />
              </Marker>
            );
          })}
        </AnimatedMap>
        <View style={styles.itemContainer}>
          {markers.map((marker: any, i: any) => {
            const { translateY, translateX, scale, opacity } = animations[i];

            return (
              <Animated.View
                key={marker.id}
                style={[
                  styles.item,
                  {
                    opacity,
                    transform: [{ translateY }, { translateX }, { scale }],
                  },
                ]}
              />
            );
          })}
        </View>
      </PanController>
    </View>
  );
}

const styles = StyleSheet.create({
  errorWrap: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    justifyContent: 'center',
  },
  container: {
    ...StyleSheet.absoluteFill,
  },
  itemContainer: {
    backgroundColor: 'transparent',
    flexDirection: 'row',
    paddingHorizontal: ITEM_SPACING / 2 + ITEM_PREVIEW,
    position: 'absolute',
    // top: screen.height - ITEM_PREVIEW_HEIGHT - 64,
    paddingTop: screen.height - ITEM_PREVIEW_HEIGHT - 64,
    // paddingTop: !ANDROID ? 0 : screen.height - ITEM_PREVIEW_HEIGHT - 64,
  },
  map: {
    backgroundColor: 'transparent',
    ...StyleSheet.absoluteFill,
  },
  item: {
    width: ITEM_WIDTH,
    height: screen.height + 2 * ITEM_PREVIEW_HEIGHT,
    backgroundColor: 'red',
    marginHorizontal: ITEM_SPACING / 2,
    overflow: 'hidden',
    borderRadius: 3,
    borderColor: '#000',
  },
});

export default AnimatedViews;
