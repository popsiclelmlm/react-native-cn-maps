import { themes as prismThemes } from 'prism-react-renderer';
import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// 站点地址：GitHub Pages（用户/组织 popsiclelmlm，项目页 react-native-cn-maps）。
const ORG = 'popsiclelmlm';
const REPO = 'react-native-cn-maps';
const GITHUB_URL = `https://github.com/${ORG}/${REPO}`;

const config: Config = {
  title: 'react-native-cn-maps',
  tagline: '兼容 react-native-maps API 的中国地图 React Native 组件库',
  favicon: 'img/logo.svg',

  // 生产地址（GitHub Pages 项目页）。
  url: `https://${ORG}.github.io`,
  baseUrl: `/${REPO}/`,

  organizationName: ORG,
  projectName: REPO,
  trailingSlash: false,

  // 文档质量守门：坏链直接让构建失败，避免 404 混进线上。
  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  // 中文优先，英文次之——目标用户是中国开发者。
  i18n: {
    defaultLocale: 'zh-Hans',
    locales: ['zh-Hans', 'en'],
    localeConfigs: {
      'zh-Hans': { label: '简体中文', htmlLang: 'zh-CN' },
      en: { label: 'English', htmlLang: 'en' },
    },
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          // 每页「编辑此页」指向仓库 website/ 目录。
          editUrl: `${GITHUB_URL}/tree/main/website/`,
          showLastUpdateTime: true,
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/logo.svg',
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'react-native-cn-maps',
      logo: {
        alt: 'react-native-cn-maps',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: '文档',
        },
        {
          to: '/docs/api',
          position: 'left',
          label: 'API',
        },
        {
          type: 'localeDropdown',
          position: 'right',
        },
        {
          href: 'https://www.npmjs.com/package/react-native-cn-maps',
          label: 'npm',
          position: 'right',
        },
        {
          href: GITHUB_URL,
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: '文档',
          items: [
            { label: '快速开始', to: '/docs/getting-started/quick-start' },
            { label: '坐标系专题', to: '/docs/guides/coordinate-systems' },
            { label: 'API 参考', to: '/docs/api' },
          ],
        },
        {
          title: '厂商',
          items: [
            { label: '高德 AMap', to: '/docs/native-setup/amap' },
            { label: '百度 Baidu', to: '/docs/native-setup/baidu' },
            { label: '腾讯 Tencent', to: '/docs/native-setup/tencent' },
            { label: '华为 Map Kit', to: '/docs/native-setup/mapkit' },
          ],
        },
        {
          title: '更多',
          items: [
            { label: 'GitHub', href: GITHUB_URL },
            {
              label: 'npm',
              href: 'https://www.npmjs.com/package/react-native-cn-maps',
            },
            {
              label: 'Discussions',
              href: `${GITHUB_URL}/discussions`,
            },
          ],
        },
      ],
      copyright: `MIT Licensed · © ${new Date().getFullYear()} react-native-cn-maps`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'json', 'json5', 'ruby', 'groovy', 'diff'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
