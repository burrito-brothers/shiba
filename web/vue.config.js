module.exports = {
  runtimeCompiler: true,
	configureWebpack: {
    optimization: {
      splitChunks: false
    }
  },
	css: {
    extract: false
  }
}
