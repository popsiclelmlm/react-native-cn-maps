import type { ReactNode } from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Translate, { translate } from '@docusaurus/Translate';
import Layout from '@theme/Layout';
import HomepageFeatures from '@site/src/components/HomepageFeatures';

import styles from './index.module.css';

function HomepageHeader() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <header className={clsx('hero', styles.heroBanner)}>
      <div className="container">
        <h1 className={styles.heroTitle}>{siteConfig.title}</h1>
        <p className={styles.heroSubtitle}>
          <Translate id="homepage.tagline">
            兼容 react-native-maps API 的中国地图 React Native 组件库
          </Translate>
        </p>
        <p className={styles.heroMeta}>
          <Translate id="homepage.meta">
            高德 · 百度 · 腾讯 · 华为地图 ｜ iOS · Android · HarmonyOS Next ｜ 新架构 (Fabric)
          </Translate>
        </p>
        <div className={styles.buttons}>
          <Link
            className="button button--secondary button--lg"
            to="/docs/getting-started/quick-start"
          >
            <Translate id="homepage.cta.start">快速开始 →</Translate>
          </Link>
          <Link
            className="button button--outline button--lg"
            style={{ color: '#fff', borderColor: '#fff' }}
            to="/docs/guides/migrate-from-react-native-maps"
          >
            <Translate id="homepage.cta.migrate">从 react-native-maps 迁移</Translate>
          </Link>
        </div>
        <div className={styles.installRow}>
          <code>yarn add react-native-cn-maps react-native-cn-maps-amap</code>
        </div>
      </div>
    </header>
  );
}

export default function Home(): ReactNode {
  return (
    <Layout
      title={translate({
        id: 'homepage.title',
        message: '中国地图 React Native 组件库',
      })}
      description="兼容 react-native-maps API 的中国地图 React Native 组件库：高德、百度、腾讯、华为地图，支持 iOS / Android / HarmonyOS Next。"
    >
      <HomepageHeader />
      <main>
        <HomepageFeatures />
      </main>
    </Layout>
  );
}
