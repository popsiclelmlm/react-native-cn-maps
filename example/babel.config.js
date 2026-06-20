const path = require('path');
const { getConfig } = require('react-native-builder-bob/babel-config');
// The library now lives in packages/core (monorepo), so point builder-bob's babel
// config at that package — that's where the `source` (src) config + sources are.
const pkg = require('../packages/core/package.json');

const root = path.resolve(__dirname, '..', 'packages', 'core');

module.exports = getConfig(
  {
    presets: ['module:@react-native/babel-preset'],
  },
  { root, pkg }
);
