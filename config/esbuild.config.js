const path = require('path');

const options = {
  entryPoints: ['app/javascript/*.js'],
  bundle: true,
  sourcemap: true,
  format: 'iife',
  outdir: 'app/assets/builds',
  publicPath: '/assets',
  loader: {
    '.js': 'jsx',
    '.png': 'file',
    '.jpg': 'file',
    '.gif': 'file',
    '.css': 'css',
  },
  assetNames: 'assets/[name]-[hash]',
  plugins: [
    {
      name: 'css-output',
      setup(build) {
        build.onResolve({ filter: /\.css$/ }, args => {
          return { path: path.resolve(args.resolveDir, args.path) };
        });
      },
    },
  ],
};

if (process.argv.includes('--watch')) {
  require('esbuild').context(options).then(context => {
    context.watch();
  });
} else {
  require('esbuild').build(options).catch(() => process.exit(1));
}
