# LiveIslands

Astro-style React and Vue component islands inside Phoenix LiveView.

LiveIslands is a framework-neutral island layer for rendering client components from Phoenix LiveView. It exposes first-class React and Vue adapters under a single Elixir package and a single JavaScript package.

LiveIslands is an independent project. It began as an extraction and redesign informed by the excellent `live_react` and `live_vue` projects, then moved to a unified React/Vue runtime with Vite, Tailwind, SSR, lazy hydration, and an agent-verifiable installation flow.

## Features

- React and Vue component entrypoints: `LiveIslands.react/1` and `LiveIslands.vue/1`
- Shared prop encoding, compact patch serialization, LiveStream patches, and event handler metadata
- React hooks for LiveView events, event replies, navigation, connection state, forms, and uploads
- Vue composables for events, navigation, forms, uploads, connection state, and slot injection
- Astro-style async islands with `client={:load | :idle | :visible | :interaction | {:media, query}}`
- Page-scoped island manifest and smart `prefetch={...}` policies for component chunks, including intent-aware prefetch
- Lazy React/Vue hook adapters, so the Phoenix entrypoint does not pay for framework runtimes before an island needs them
- Deferred server islands with signed SSR fetches, fallback HTML, cache headers, and runtime timing events
- Vite manifest verification for lazy island chunks in production builds
- Vite manifest asset tags for production content-hashed entrypoints
- First-class server-only islands with `<.react_server>` and `<.vue_server>`
- Server-only zero-JS proofs for hookless React and Vue SSR islands
- Route-level CSS-only shells for pages that should skip the app JavaScript entry
- Vite and NodeJS SSR adapters under the `LiveIslands.SSR` namespace
- Production benchmark suite for initial route bytes, SSR assertions, server-only zero-JS proofs, lazy chunks, KaTeX, and PDF.js

## Package Exports

```js
import {
  createReactIsland,
  getHooks as getReactHooks,
} from "live_islands/react";
import { createReactIsland as createReactIslandRegistry } from "live_islands/react/app";
import { getHooks as getVueHooks, createVueIsland } from "live_islands/vue";
import {
  defineClientStrategy,
  definePrefetchStrategy,
  getIslandHooks,
  getIslandManifest,
  getPageIslandManifest,
} from "live_islands";
```

Use `live_islands/react/app` for client component registries that only need
`createReactIsland`; it avoids importing React hooks, context helpers, and Link
helpers into the page entry.

The root export stays framework-neutral. Import framework helpers from
`live_islands/react`, `live_islands/react/app`, or `live_islands/vue`, then pass
those registries into `getIslandHooks`:

```js
const modules = import.meta.glob("./react-components/**/*.jsx");

const hooks = getIslandHooks({
  react: createReactIsland({
    availableComponents: modules,
    resolve: (name) => modules[`./react-components/${name}.jsx`]?.(),
    preloadUrls: (name) => viteManifestUrlsFor(name),
  }),
  vue: createVueIsland({ resolve: vueResolver }),
  prefetch: { scope: "page" },
});
```

## Phoenix Usage

```elixir
def html_helpers do
  quote do
    import LiveIslands
  end
end
```

```heex
<.react name="DashboardCard" title={@title} client={:visible} prefetch={:idle} />

<.vue v-component="UserPanel" client={:visible} prefetch={:hover} user={@user} v-on:save={JS.push("save")} />

<.react name="ExpensiveChart" client={:visible} prefetch={:intent} />

<.react_server name="StaticCard" title={@title} />

<.react_server name="SlowReport" defer={true} defer_cache_control="public, max-age=60">
  <:fallback>Loading report...</:fallback>
</.react_server>
```

Deferred server islands need the signed endpoint mounted in your router:

```elixir
config :live_islands, deferred_endpoint: MyAppWeb.Endpoint
```

```elixir
forward "/live-islands/deferred", LiveIslands.Deferred,
  endpoint: MyAppWeb.Endpoint
```

## Install

```elixir
def deps do
  [
    {:live_islands, git: "https://github.com/lulucatdev/live_islands"}
  ]
end
```

```bash
mix deps.get
mix live_islands.install
mix live_islands.verify_install
mix live_islands.verify_install --full --install
```

`mix live_islands.install` is a scaffold copier only. It preserves existing project files and does not remove daisyUI or rewrite your Phoenix asset pipeline. Use [the installation guide](guides/installation.md) or [the install skill](skills/live-islands-install/SKILL.md) to wire the project intentionally, then run the static and full verifiers.

## Benchmarks

Run the production benchmark suite from the repo root:

```bash
npm run benchmarks
```

It builds the example app, starts Phoenix in `MIX_ENV=prod`, opens Chromium, takes multiple samples per page, records the test environment, verifies SSR/server-only/deferred islands, proves `/server-only` does not attach hooks, hydrate islands, prefetch chunks, load React/Vue component chunks, or load the app JavaScript entry, measures initial route bytes, records FCP/LCP/hydration/deferred/prefetch timing, checks route-to-route LiveView navigation, proves intent prefetch waits for an explicit signal, and clicks through a deferred KaTeX + PDF.js workload. Results are written to `benchmarks/results/latest.json` and `benchmarks/results/latest.md`; release tags also publish those files as GitHub Release assets and append the benchmark summary to the release notes.

## Credits

LiveIslands is built with gratitude for the upstream projects that made the direction clear:

- [mrdotb/live_react](https://github.com/mrdotb/live_react)
- [Valian/live_vue](https://github.com/Valian/live_vue)

See [NOTICE.md](NOTICE.md) for attribution and license notes.
