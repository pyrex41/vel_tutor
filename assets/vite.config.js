import { defineConfig } from 'vite'
import { resolve } from 'path'

export default defineConfig(({ mode }) => ({
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
        entryFileNames: 'js/[name]-[hash].js',
        chunkFileNames: 'js/[name]-[hash].js',
        assetFileNames: assetInfo => {
          if (assetInfo.name.endsWith('.css')) {
            return 'css/[name]-[hash][extname]'
          }
          return 'assets/[name]-[hash][extname]'
        }
      },
      external: mode === 'production' ? ['phoenix', 'phoenix_html', 'phoenix_live_view'] : []
    },
    outDir: '../priv/static/assets'
  },
  css: {
    postcss: {
      plugins: [require('@tailwindcss/postcss'), require('autoprefixer')]
    }
  },
  server: {
    host: '0.0.0.0',
    port: 4001,
    hmr: {
      port: 4001
    }
  }
}))