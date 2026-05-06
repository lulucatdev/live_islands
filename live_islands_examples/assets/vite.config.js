import path from "path";
import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";

import react from "@vitejs/plugin-react";
import vue from "@vitejs/plugin-vue";
import liveIslandsPlugin from "live_islands/vite-plugin";

// https://vitejs.dev/config/
export default defineConfig(({ command }) => {
  const isDev = command !== "build";
  const isSsrBuild = process.argv.includes("--ssr");
  const useHashedAssets = !isDev && !isSsrBuild;

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
      dedupe: ["react", "react-dom", "vue"],
      alias: {
        "@": path.resolve(__dirname, "."),
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
      manifest: true,
      rollupOptions: {
        input: {
          app: path.resolve(__dirname, "./js/app.js"),
        },
        output: {
          entryFileNames: useHashedAssets ? "[name]-[hash].js" : "[name].js",
          chunkFileNames: useHashedAssets ? "[name]-[hash].js" : "[name].js",
          assetFileNames: useHashedAssets
            ? "[name]-[hash][extname]"
            : "[name][extname]",
        },
      },
    },
  };
});
