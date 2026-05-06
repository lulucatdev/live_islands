import path from "path";
import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";

import react from "@vitejs/plugin-react";
import vue from "@vitejs/plugin-vue";
import liveIslandsPlugin from "live_islands/vite-plugin";

// https://vitejs.dev/config/
export default defineConfig(({ command }) => {
  const isDev = command !== "build";
  const mixEnv = process.env.MIX_ENV || "dev";

  return {
    base: isDev ? undefined : "/assets",
    publicDir: "static",
    plugins: [react(), vue(), liveIslandsPlugin(), tailwindcss()],
    ssr: {
      // we need it, because in SSR build we want no external
      // and in dev, we want external for fast updates
      noExternal: isDev ? undefined : true,
    },
    resolve: {
      alias: {
        "@": path.resolve(__dirname, "."),
        "phoenix-colocated": path.resolve(
          __dirname,
          `../_build/${mixEnv}/phoenix-colocated`,
        ),
      },
    },
    optimizeDeps: {
      // these packages are loaded as file:../deps/<name> imports
      // so they're not optimized for development by vite by default
      // we want to enable it for better DX
      // more https://vitejs.dev/guide/dep-pre-bundling#monorepos-and-linked-dependencies
      include: [
        "live_islands",
        "live_islands/react",
        "live_islands/vue",
        "phoenix",
        "phoenix_html",
        "phoenix_live_view",
      ],
    },
    build: {
      commonjsOptions: { transformMixedEsModules: true },
      target: "es2020",
      outDir: "../priv/static/assets", // emit assets to priv/static/assets
      emptyOutDir: true,
      sourcemap: isDev, // enable source map in dev build
      manifest: false, // do not generate manifest.json
      rollupOptions: {
        input: {
          app: path.resolve(__dirname, "./js/app.js"),
        },
        output: {
          // remove hashes to match phoenix way of handling asssets
          entryFileNames: "[name].js",
          chunkFileNames: "[name].js",
          assetFileNames: "[name][extname]",
        },
      },
    },
  };
});
