// Set WEBPACK_MODE=development for development builds
module.exports = (env, argv) => ({
  mode: process.env.WEBPACK_MODE || 'production',
  optimization: {
    minimize: false,
  },
});
