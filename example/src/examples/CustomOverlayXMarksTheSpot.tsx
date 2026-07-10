import { View } from 'react-native';
import { Polygon, Polyline, Marker } from 'react-native-cn-maps';

function XMarksTheSpot(props: any) {
  return (
    <View>
      <Polygon
        coordinates={props.coordinates}
        strokeColor="rgba(0, 0, 0, 1)"
        strokeWidth={3}
      />
      <Polyline coordinates={[props.coordinates[0], props.coordinates[2]]} />
      <Polyline coordinates={[props.coordinates[1], props.coordinates[3]]} />
      <Marker coordinate={props.center} />
    </View>
  );
}

export default XMarksTheSpot;
