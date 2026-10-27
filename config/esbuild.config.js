const path = require('path');

const watch = process.argv.includes('--watch');
const production = process.env.RAILS_ENV === 'production';

require('esbuild').context({
  entryPoints: ['app/javascript/application.js'],
  bundle: true,
  outdir: 'app/assets/builds',
  absWorkingDir: path.join(process.cwd()),
  sourcemap: production ? 'linked' : true,
  minify: production,
  define: { 'process.env.NODE_ENV': JSON.stringify(production ? 'production' : 'development') },
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
    context.rebuild().then(() => {
      context.dispose();
    });
  }
}).catch(() => process.exit(1));
