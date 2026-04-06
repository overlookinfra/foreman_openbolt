// Extend @theforeman/test's plugin config with jest-dom matchers.
// The plugin config provides the module resolver, transforms, and
// setup files needed to test Foreman plugins with PatternFly 5.
const pluginConfig = require('@theforeman/test/src/pluginConfig');

module.exports = {
  ...pluginConfig,
  setupFilesAfterEnv: [
    ...(pluginConfig.setupFilesAfterEnv || []),
    '@testing-library/jest-dom',
  ],
};
