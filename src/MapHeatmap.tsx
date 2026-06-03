import { useWarnNotImplemented } from './_warnings';
import type { HeatmapProps } from './types';

export type HeatmapComponent = ((props: HeatmapProps) => null) & {
  __MAP_HEATMAP: true;
};

export const Heatmap: HeatmapComponent = function Heatmap(
  _props: HeatmapProps
) {
  useWarnNotImplemented('Heatmap');
  return null;
} as HeatmapComponent;

Heatmap.__MAP_HEATMAP = true;

export default Heatmap;
export type { HeatmapProps as MapHeatmapProps };
