const path = require('path');
const rails = require('esbuild-rails');

const watch = process.argv.includes('--watch');

require('esbuild').context({
  entryPoints: ['app/javascript/application.js'],
  bundle: true,
  outdir: 'app/assets/builds',
  absWorkingDir: path.join(process.cwd()),
  plugins: [rails()],
  sourcemap: true,
  format: 'iife',
  loader: {
    '.js': 'jsx',
    '.jsx': 'jsx',
    '.png': 'file',
    '.jpg': 'file',
    '.gif': 'file',
    '.svg': 'file',
  },
  assetNames: 'assets/[name]-[hash]',
}).then(context => {
  if (watch) {
    context.watch();
  } else {
    context.rebuild().then(result => {
      context.dispose();
    });
  }
}).catch(() => process.exit(1));
