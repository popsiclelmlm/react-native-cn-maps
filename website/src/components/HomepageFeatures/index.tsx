import type { ReactNode } from 'react';
import clsx from 'clsx';
import Translate from '@docusaurus/Translate';
import Heading from '@theme/Heading';
import { Puzzle, Map, MapPin, Smartphone, Lock, Zap } from 'lucide-react';
import styles from './styles.module.css';

type FeatureItem = {
  icon: ReactNode;
  title: ReactNode;
  description: ReactNode;
};

const FeatureList: FeatureItem[] = [
  {
    icon: <Puzzle />,
    title: <Translate id="feature.parity.title">对齐 react-native-maps</Translate>,
    description: (
      <Translate id="feature.parity.desc">
        MapView、Marker、Callout、Polyline、Polygon、Circle、Overlay、瓦片图层、Heatmap、Geojson
        全量组件。多数迁移只需改一行 import。
      </Translate>
    ),
  },
  {
    icon: <Map />,
    title: <Translate id="feature.providers.title">多厂商，按需安装</Translate>,
    description: (
      <Translate id="feature.providers.desc">
        高德 / 百度 / 腾讯 / 华为地图各自独立发包，核心包与厂商适配器分离，不会把用不到的
        SDK 打进应用。
      </Translate>
    ),
  },
  {
    icon: <MapPin />,
    title: <Translate id="feature.coordinate.title">坐标系自动转换</Translate>,
    description: (
      <Translate id="feature.coordinate.desc">
        声明输入坐标系（wgs84 / gcj02 / bd09），库在 JS 层转换为所选厂商的原生坐标系，告别偏移。
      </Translate>
    ),
  },
  {
    icon: <Smartphone />,
    title: <Translate id="feature.harmony.title">三端 · 新架构</Translate>,
    description: (
      <Translate id="feature.harmony.desc">
        iOS、Android，以及基于 RNOH 的 HarmonyOS Next。纯 Fabric 组件 + TurboModule，无旧桥。
      </Translate>
    ),
  },
  {
    icon: <Lock />,
    title: <Translate id="feature.privacy.title">隐私合规优先</Translate>,
    description: (
      <Translate id="feature.privacy.desc">
        库绝不代为同意隐私政策，由宿主应用按 PIPL 显式声明，满足应用商店审核要求。
      </Translate>
    ),
  },
  {
    icon: <Zap />,
    title: <Translate id="feature.native.title">原生能力直达</Translate>,
    description: (
      <Translate id="feature.native.desc">
        渐变折线、图片地面覆盖物、热力图、自定义瓦片、KML/GeoJSON——直接映射到各家原生 SDK。
      </Translate>
    ),
  },
];


function Feature({ icon, title, description }: FeatureItem) {
  return (
    <div className={clsx('col col--4', styles.col)}>
      <div className={styles.card}>
        <div className={styles.cardIcon}>{icon}</div>
        <Heading as="h3" className={styles.cardTitle}>
          {title}
        </Heading>
        <p className={styles.cardBody}>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): ReactNode {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
