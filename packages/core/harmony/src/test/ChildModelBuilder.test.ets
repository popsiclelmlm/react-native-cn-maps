/*
 * L1 unit tests for the dumb-child props→model builder — pure, no map SDK, no
 * device. Props are built as Record<string, Object> (bracket-assigned, ArkTS-clean).
 */
import { describe, it, expect } from '@ohos/hypium';
import { buildMarkerModel, buildOverlayModel } from '../main/ets/host/ChildModelBuilder';
import { CnHeatmapModel, CnPolylineModel, CnUrlTileModel } from '../main/ets/adapter/CnMapModels';

function ll(lat: number, lng: number): Record<string, Object> {
  const r: Record<string, Object> = {};
  r['latitude'] = lat;
  r['longitude'] = lng;
  return r;
}

export default function childModelBuilderTest() {
  describe('ChildModelBuilder', () => {
    it('buildMarkerModel reads nested coordinate + props', 0, () => {
      const props: Record<string, Object> = {};
      props['coordinate'] = ll(1, 2);
      props['title'] = 'Hi';
      props['description'] = 'desc';
      props['draggable'] = true;
      props['pinColor'] = '#ff0000';
      props['rotation'] = 45;
      const m = buildMarkerModel(props);
      expect(m.latitude).assertEqual(1);
      expect(m.longitude).assertEqual(2);
      expect(m.title).assertEqual('Hi');
      expect(m.snippet).assertEqual('desc');   // description → snippet
      expect(m.draggable).assertTrue();
      expect(m.pinColor).assertEqual('#ff0000');
      expect(m.rotation).assertEqual(45);
      expect(m.hasInfoWindowContent).assertTrue();
    });

    it('buildMarkerModel supports flattened lat/lng + anchor + defaults', 0, () => {
      const props: Record<string, Object> = {};
      props['latitude'] = 10;
      props['longitude'] = 20;
      const anchor: Record<string, Object> = {};
      anchor['x'] = 0.3;
      anchor['y'] = 0.7;
      props['anchor'] = anchor;
      const m = buildMarkerModel(props);
      expect(m.latitude).assertEqual(10);
      expect(m.anchorU).assertEqual(0.3);
      expect(m.anchorV).assertEqual(0.7);
      expect(m.opacity).assertEqual(1.0);   // default
      expect(m.draggable).assertFalse();    // default
    });

    it('buildOverlayModel polyline parses coords + dashed + tappable', 0, () => {
      const props: Record<string, Object> = {};
      const coords: Object[] = [ll(1, 1), ll(2, 2)];
      props['coordinates'] = coords;
      props['strokeWidth'] = 4;
      const dash: number[] = [2, 2];
      props['lineDashPattern'] = dash;
      props['tappable'] = true;
      const model = buildOverlayModel('RNMapsPolyline', props);
      expect(model !== null).assertTrue();
      const pl = model as CnPolylineModel;
      expect(pl.kind).assertEqual('polyline');
      expect(pl.coordinates.length).assertEqual(2);
      expect(pl.strokeWidth).assertEqual(4);
      expect(pl.dashed).assertTrue();
      expect(pl.tappable).assertTrue();
    });

    it('buildOverlayModel heatmap parses points JSON', 0, () => {
      const props: Record<string, Object> = {};
      props['points'] = '[{"latitude":1,"longitude":2,"weight":3}]';
      props['radius'] = 25;
      const hm = buildOverlayModel('RNMapsHeatmap', props) as CnHeatmapModel;
      expect(hm.kind).assertEqual('heatmap');
      expect(hm.points.length).assertEqual(1);
      expect(hm.points[0].weight).assertEqual(3);
      expect(hm.radius).assertEqual(25);
    });

    it('buildOverlayModel urlTile maps overlayZIndex→zIndex', 0, () => {
      const props: Record<string, Object> = {};
      props['urlTemplate'] = 'https://x/{z}/{x}/{y}.png';
      props['minimumZ'] = 2;
      props['overlayZIndex'] = 5;
      const t = buildOverlayModel('RNMapsUrlTile', props) as CnUrlTileModel;
      expect(t.urlTemplate).assertEqual('https://x/{z}/{x}/{y}.png');
      expect(t.minimumZ).assertEqual(2);
      expect(t.zIndex).assertEqual(5);
    });

    it('buildOverlayModel returns null for an unknown component', 0, () => {
      const props: Record<string, Object> = {};
      expect(buildOverlayModel('RNMapsUnknown', props)).assertNull();
    });
  });
}
