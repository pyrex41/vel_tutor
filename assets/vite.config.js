import { defineConfig } from 'vite'
import { resolve } from 'path'

export default defineConfig(({ mode }) => ({
  base: mode === 'production' ? '/assets/' : '/assets/',
  plugins: [],
  resolve: {
    alias: {
      phoenix: resolve(__dirname, '../deps/phoenix/assets/js/phoenix/index.js'),
      phoenix_html: resolve(__dirname, '../deps/phoenix_html/priv/static/phoenix_html.js'),
      phoenix_live_view: resolve(__dirname, '../deps/phoenix_live_view/assets/js/phoenix_live_view/index.ts'),
      morphdom: resolve(__dirname, 'node_modules/morphdom/dist/morphdom-esm.js')
    }
  },
  build: {
    rollupOptions: {
      input: {
        app: resolve(__dirname, 'js/app.js'),
      },
      output: {
        // In development: no hashes for simple paths
        // In production: use hashes for cache busting
        entryFileNames: mode === 'production' ? 'js/app-[hash].js' : 'js/app.js',
        chunkFileNames: mode === 'production' ? 'js/[name]-[hash].js' : 'js/[name].js',
        assetFileNames: assetInfo => {
          if (assetInfo.name.endsWith('.css')) {
            return mode === 'production' ? 'css/app-[hash][extname]' : 'css/app[extname]'
          }
          return mode === 'production' ? 'assets/[name]-[hash][extname]' : 'assets/[name][extname]'
        }
      },
      external: mode === 'production' ? ['phoenix', 'phoenix_html', 'phoenix_live_view'] : []
    },
    outDir: '../priv/static/assets',
    emptyOutDir: false,  // Don't delete other files in priv/static
    manifest: mode === 'production'  // Generate manifest.json in production
  },
  css: {
    postcss: {
      plugins: [require('@tailwindcss/postcss'), require('autoprefixer')]
    }
  },
  server: {
    host: '0.0.0.0',
    port: 4001,
    strictPort: true,  // Fail if port is already taken
    hmr: {
      host: 'localhost',
      port: 4001,
      overlay: true  // Show errors in browser overlay
    },
    // Proxy non-asset requests back to Phoenix
    proxy: {
      '/socket': {
        target: 'http://localhost:4000',
        ws: true
      },
      '/live': 'http://localhost:4000'
    }
  }
}))
