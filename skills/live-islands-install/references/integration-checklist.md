# Integration Checklist

LiveIslands requires these project-level integration points.

## Elixir

- Add `{:live_islands, ...}` to `mix.exs`.
- Import `LiveIslands` inside `html_helpers/0` in `lib/*_web.ex` so `<.react>` and `<.vue>` are available.
- Add `config :live_islands` in `config/config.exs` or an environment config.
- For development SSR, set `ssr_module: LiveIslands.SSR.ViteJS` and `vite_host`.
- For production SSR, set `ssr_module: LiveIslands.SSR.NodeJS` and add `NodeJS.Supervisor` to the supervision tree. If the user does not want SSR, set `ssr: false` and skip the supervisor.

## Assets

- Ensure `assets/package.json` includes:
  - `live_islands`
  - `vite`
  - `tailwindcss`
  - `@tailwindcss/vite`
  - `@vitejs/plugin-react`
  - `@vitejs/plugin-vue`
  - `react`
  - `react-dom`
  - `vue`
- Ensure `assets/vite.config.*` includes Tailwind, React, Vue, and `live_islands/vite-plugin`.
- If Phoenix colocated hooks are imported from `phoenix-colocated/<app>`, add a Vite alias to `_build/${MIX_ENV || "dev"}/phoenix-colocated`.
- Ensure `assets/js/app.js` imports `getIslandHooks`, React components, and Vue components, then combines them with any existing hooks.
- Enable `getIslandHooks({ react, vue, prefetch: true })` when the app wants page-aware island chunk prefetching.
- Prefer async React/Vue component registries so Vite can split page-specific island chunks.
- Ensure `assets/js/server.js` can dispatch SSR to both React and Vue renderers.
- Ensure `assets/react-components/index.{js,jsx,ts,tsx}` and `assets/vue-components/index.{js,ts}` exist.
- Use async registries in both roots (`import()` or `import.meta.glob`) so Vite emits lazy chunks.
- Ensure `assets/css/app.css` imports Tailwind and scans `../react-components` and `../vue-components`.
- Ensure root layout loads Vite assets in development, usually with `LiveIslands.Reload.vite_assets`.

## Tailwind and daisyUI

LiveIslands does not require removing daisyUI.

- Keep existing `assets/css/app.css` unless the user asks for a replacement.
- Add Tailwind source coverage for React and Vue component directories.
- Preserve existing `@plugin`, `@theme`, `@custom-variant`, and design-system CSS.
- If the project uses Phoenix 1.8 default daisyUI vendor plugins, they can stay as long as the Vite/Tailwind build passes.

## Lazy Hydration

LiveIslands supports per-island hydration strategies:

- `client={:load}` for immediate hydration. This is the default.
- `client={:idle}` for idle-time hydration.
- `client={:visible}` for viewport-triggered hydration.
- `client={{:media, "(min-width: 1024px)"}}` for media-query hydration.
- `client={:none}` for SSR-only static islands.

Use these strategies to keep heavy islands out of the initial interactive path.

## Page-Aware Prefetch

LiveIslands can preload island component chunks without hydrating the island:

- `prefetch={:load}` preloads as soon as the current page is scanned.
- `prefetch={:idle}` preloads during idle time.
- `prefetch={:visible}` preloads when the island enters the viewport.
- `prefetch={:hover}` preloads when the island receives pointer or focus intent.
- `prefetch={:tap}` preloads on pointer/touch down.
- `prefetch={{:media, "(min-width: 1024px)"}}` preloads when a media query matches.
- `prefetch={:none}` disables prefetch. This is the default.

## Optional Scaffold

`mix live_islands.install` copies missing template files from `assets/copy` into the target project's `assets/` directory. It preserves existing files and does not wire the project automatically.
