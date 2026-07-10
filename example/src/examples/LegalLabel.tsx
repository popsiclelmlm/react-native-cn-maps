import { useState, useRef, useEffect } from 'react';
import {
  StyleSheet,
  View,
  Text,
  Animated,
  Dimensions,
  TouchableOpacity,
} from 'react-native';

import MapView, { Marker } from 'react-native-cn-maps';

const screen = Dimensions.get('window');

function LegalLabel(props: any) {
  // 只创建一次的 Animated 值，跨渲染保持同一实例
  const _legalLabelPositionY = useRef(new Animated.Value(10)).current;
  const [legalLabelPositionY, setLegalLabelPositionY] = useState(10);

  useEffect(() => {
    _legalLabelPositionY.addListener(({ value }) => {
      setLegalLabelPositionY(value);
    });
    return () => {
      _legalLabelPositionY.removeAllListeners();
    };
  }, [_legalLabelPositionY]);

  const onPressAnimate = () => {
    Animated.sequence([
      Animated.spring(_legalLabelPositionY, {
        toValue: 100,
        useNativeDriver: true,
      }),
      Animated.spring(_legalLabelPositionY, {
        toValue: 10,
        useNativeDriver: true,
      }),
    ]).start();
  };

  const latlng = {
    latitude: 31.2304,
    longitude: 121.4737,
  };

  const ASPECT_RATIO = screen.width / screen.height;
  const LATITUDE_DELTA = 0.0922;
  const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

  return (
    <View style={{ ...StyleSheet.absoluteFill }}>
      <MapView
        provider={props.provider}
        style={styles.map}
        legalLabelInsets={{
          top: 0,
          left: 0,
          bottom: legalLabelPositionY,
          right: 10,
        }}
        initialRegion={{
          ...latlng,
          latitudeDelta: LATITUDE_DELTA,
          longitudeDelta: LONGITUDE_DELTA,
        }}
      >
        <Marker coordinate={latlng} />
      </MapView>

      <View style={styles.username}>
        <TouchableOpacity onPress={onPressAnimate}>
          <Text style={styles.usernameText}>播放动画</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.bio}>
        <Text style={styles.bioText}>
          个人简介占位文本，这里可以写一段关于自己的介绍。点击上方「播放动画」，
          可以看到地图版权标签随布局位置上下移动的效果。
        </Text>
      </View>

      <View style={styles.photo}>
        <View style={styles.photoInner}>
          <Text style={styles.photoText}>头像</Text>
        </View>
      </View>
    </View>
  );
}

const padding = 10;
const photoSize = 80;
const mapHeight = screen.height - 130;
const styles = StyleSheet.create({
  bio: {
    marginHorizontal: padding,
    marginBottom: 0,
    paddingVertical: padding / 2,
  },
  bioText: {
    fontSize: 16,
    lineHeight: 16 * 1.5,
  },
  username: {
    paddingLeft: photoSize + padding + padding,
    paddingTop: padding,
  },
  usernameText: {
    fontSize: 36,
    lineHeight: 36,
    color: 'blue',
    textDecorationLine: 'underline',
  },
  photo: {
    padding: 2,
    position: 'absolute',
    top: mapHeight - photoSize / 2,
    left: padding,
    borderRadius: 5,
    borderWidth: StyleSheet.hairlineWidth,
    backgroundColor: '#ccc',
    width: photoSize,
    height: photoSize,
  },
  photoInner: {
    alignItems: 'center',
    justifyContent: 'center',
    flex: 1,
  },
  photoText: {
    fontSize: 9,
    textAlign: 'center',
  },
  map: {
    height: mapHeight,
  },
});

export default LegalLabel;
