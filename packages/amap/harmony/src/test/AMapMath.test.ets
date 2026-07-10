/*
 * L1 unit tests for the pure AMap math helpers — no map SDK, no device. Run with
 * `hvigorw test` / DevEco's local test runner (@ohos/hypium).
 */
import { describe, it, expect } from '@ohos/hypium';
import { markerHue, parseColor, rnRotationToAMap, wmsUrl } from '../main/ets/AMapMath';

export default function aMapMathTest() {
  describe('AMapMath', () => {
    it('rnRotationToAMap inverts clockwise→counterclockwise', 0, () => {
      expect(rnRotationToAMap(0)).assertEqual(0);
      expect(rnRotationToAMap(90)).assertEqual(270);
      expect(rnRotationToAMap(360)).assertEqual(0);
      expect(rnRotationToAMap(45)).assertEqual(315);
    });

    it('markerHue parses primary colors to HSV hue', 0, () => {
      expect(markerHue('#ff0000')).assertEqual(0);
      expect(markerHue('#00ff00')).assertEqual(120);
      expect(markerHue('#0000ff')).assertEqual(240);
    });

    it('markerHue handles shorthand / alpha / null / invalid', 0, () => {
      expect(markerHue('#f00')).assertEqual(0);       // shorthand
      expect(markerHue('#ffff0000')).assertEqual(0);  // AARRGGBB drops alpha
      expect(markerHue(null)).assertNull();
      expect(markerHue('notacolor')).assertNull();
    });

    it('parseColor returns rgb triple or null', 0, () => {
      const rgb = parseColor('#102030');
      expect(rgb !== null).assertTrue();
      if (rgb !== null) {
        expect(rgb[0]).assertEqual(16);
        expect(rgb[1]).assertEqual(32);
        expect(rgb[2]).assertEqual(48);
      }
      expect(parseColor('xyz')).assertNull();
    });

    it('wmsUrl substitutes the EPSG:3857 bbox placeholders', 0, () => {
      const url = wmsUrl('bbox={minX},{minY},{maxX},{maxY}&w={width}&h={height}', 0, 0, 1, 256);
      expect(url.indexOf('{minX}') === -1).assertTrue();
      expect(url.indexOf('{maxY}') === -1).assertTrue();
      expect(url.indexOf('w=256') >= 0).assertTrue();
      expect(url.indexOf('h=256') >= 0).assertTrue();
    });
  });
}
