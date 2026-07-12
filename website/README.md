# 文档站（website/）

[react-native-cn-maps](https://github.com/popsiclelmlm/react-native-cn-maps) 的官方文档站，基于 [Docusaurus 3](https://docusaurus.io/) 构建，中英双语（中文优先）。

> 本目录**独立于仓库根的 yarn workspace**，用 npm 单独管理依赖，不影响库本身的安装与构建。

## 本地开发

```sh
cd website
npm install
npm run start          # 默认中文 http://localhost:3000/react-native-cn-maps/
npm run start:en       # 英文预览
```

> Docusaurus 的热更新对「新增 locale 文件」不敏感，改多语言内容后可能需要重启 dev server。

## 构建与预览

```sh
npm run build          # 产物输出到 website/build
npm run serve          # 本地静态预览构建产物
```

## 部署

推送到 `main` 且改动 `website/**` 时，由 [`.github/workflows/deploy-docs.yml`](../.github/workflows/deploy-docs.yml) 自动构建并发布到 GitHub Pages。

首次启用需在仓库 **Settings → Pages → Build and deployment → Source** 选择 **GitHub Actions**。

## 目录结构

```
website/
├── docs/                     # 中文文档（默认 locale）
│   ├── intro.md
│   ├── getting-started/      # 安装 / 快速开始 / 选择厂商
│   ├── native-setup/         # 分厂商原生配置
│   ├── guides/               # 坐标系 / 隐私合规 / 迁移 / 支持矩阵
│   └── api/                  # 13 个组件 API 参考
├── i18n/en/                  # 英文翻译（未翻译的页面自动回退到中文）
├── src/                      # 首页与自定义组件
├── sidebars.ts               # 侧边栏 = 信息架构
└── docusaurus.config.ts      # 站点配置
```

## 写作约定

- **新增文档页**：在 `docs/` 下建 md，并在 [`sidebars.ts`](./sidebars.ts) 登记。
- **API 页事实来源**：`packages/core/src/types.ts`（props/事件类型）与各组件源码。改 API 时同步更新对应 API 页。
- **英文翻译**：把中文页复制到 `i18n/en/docusaurus-plugin-content-docs/current/` 对应路径后翻译；未翻译的页面会自动回退到中文版，不会 404。
  - ⚠️ **成块翻译**：`onBrokenLinks: 'throw'` 下，翻译页里的相对 `.md` 链接只有在**目标页也已翻译**时才能解析——只翻译单页却链向未翻译的兄弟页会让构建失败。要么整块（如整个 `guides/`）一起翻译，要么先不加跨页 `.md` 链接。当前 UI 层（首页、导航、页脚）已英译，正文页整体回退中文。
