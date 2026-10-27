const fs = require('fs');
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
  // MapLibre looks for its worker beside itself via import.meta.url, which an
  // IIFE bundle doesn't have; application.js points it at the copy below instead.
  logOverride: { 'empty-import-meta': 'silent' },
}).then(context => {
  if (watch) {
    context.watch();
  } else {
    context.rebuild().then(() => {
      context.dispose();
    });
  }
}).catch(() => process.exit(1));

// MapLibre's web worker is a self-contained ES module; Propshaft serves it from
// the builds directory with a digest.
fs.copyFileSync(
  require.resolve('maplibre-gl/dist/maplibre-gl-worker.mjs'),
  path.join(process.cwd(), 'app/assets/builds/maplibre-gl-worker.js')
);
