# Lazy Islands

LiveIslands supports Astro-style selective hydration for Phoenix LiveView.

The page still arrives as LiveView-rendered HTML. Each island then decides when to load its component module and hydrate:

```heex
<.react name="Chart" client={:visible} ssr={true} />
<.vue v-component="Filters" client={:idle} v-ssr={true} />
<.react name="WideMap" client={{:media, "(min-width: 1024px)"}} />
<.react name="Details" client={:interaction} />
<.react_server name="StaticCard" />
```

## Client Strategies

- `:load` hydrates as soon as the LiveView hook mounts. This is the default.
- `:idle` waits for `requestIdleCallback`, with a timeout fallback.
- `:visible` waits until the island enters the viewport.
- `:interaction` waits for pointer, touch, or focus intent.
- `{:media, query}` waits until `window.matchMedia(query)` matches.
- `:none` never hydrates. Use this only with SSR when you want static HTML.

These strategies are per-island, so a page can hydrate a small navigation island immediately and defer a heavy chart until it is visible.

Custom client strategies can be registered in JavaScript and referenced from Elixir with `client={{:custom, "name"}}`:

```js
import { defineClientStrategy } from "live_islands";

defineClientStrategy("after-transition", (el, hydrate) => {
  el.addEventListener("transitionend", hydrate, { once: true });
  return () => el.removeEventListener("transitionend", hydrate);
});
```

## Page-Aware Prefetch

Hydration decides when an island mounts. Prefetch decides when its component module is loaded into the browser cache.

Enable the page-aware prefetch runtime next to your hooks:

```js
const hooks = getIslandHooks({
  react: reactComponents,
  vue: vueComponents,
  prefetch: { scope: "page" },
});
```

Then annotate islands with `prefetch`:

```heex
<.react name="Chart" client={:visible} prefetch={:idle} />
<.vue v-component="Filters" client={:idle} prefetch={:hover} />
<.react name="ExpensiveChart" client={:visible} prefetch={:intent} />
<.react name="WideMap" client={:visible} prefetch={{:media, "(min-width: 1024px)"}} />
```

Supported prefetch policies are `:load`, `:idle`, `:visible`, `:hover`, `:tap`, `:interaction`, `:intent`, `{:media, query}`, and `:none`.

The runtime builds a manifest from the current LiveView DOM using each island's `data-framework` and `data-name`. It only preloads chunks for islands present on the current page, and it does not hydrate or mount the component early. Prefetches run through a small bounded priority queue and dispatch `live-islands:prefetch:queue`, `live-islands:prefetch:start`, `live-islands:prefetch:modulepreload`, `live-islands:prefetch:load`, `live-islands:prefetch:skip`, and `live-islands:prefetch:error`, so browser tests and benchmarks can prove that prefetch remains page scoped.

Use `prefetch={:intent}` for expensive components where a visible island is a useful hint, but a real pointer, focus, or touch signal should win. Soft visible prefetch runs at low priority and is skipped when the browser reports save-data or a slow 2g connection. Pointer, focus, and touch intent runs at high priority and can reprioritize a queued job.

You can inspect the page-scoped manifest in application code or browser tests:

```js
import { getPageIslandManifest } from "live_islands";

console.table(getPageIslandManifest());
```

Use `getIslandManifest({ scope: "document" })` when you deliberately want to inspect every island in the document. The prefetch controller uses `scope: "page"` by default and rescans after LiveView navigation.

Custom prefetch strategies use the same shape:

```js
import { definePrefetchStrategy } from "live_islands";

definePrefetchStrategy("after-search-open", (el, preload) => {
  window.addEventListener("search:open", () => preload(el), { once: true });
});
```

## Async Component Registries

React and Vue can both resolve components asynchronously. This lets Vite split component files into separate chunks and load only the islands present on the current page.

React:

```js
import { createReactIsland } from "live_islands/react";

const components = {
  Chart: () => import("./chart"),
  Filters: () => import("./filters"),
};

export default createReactIsland({
  availableComponents: components,
  resolve: (name) => components[name]?.(),
  preloadUrls: (name) => viteManifestUrlsFor(name),
});
```

Vue:

```js
import { createVueIsland } from "live_islands/vue";

const modules = import.meta.glob("./**/*.vue");

export default createVueIsland({
  resolve: (name) => modules[`./${name}.vue`]?.(),
  preloadUrls: (name) => viteManifestUrlsFor(name),
});
```

You can still pass a plain synchronous component map. Async registries are the recommended default for larger apps.

`preloadUrls(name)` is optional. When provided, it should return concrete module URLs, usually from the Vite manifest, and LiveIslands inserts them as `<link rel="modulepreload">` before resolving the component. The runtime includes the inserted URL count in the `live-islands:prefetch:modulepreload` and `live-islands:prefetch:load` events.

Run the full installer verifier after wiring async registries. It checks that the client build actually emitted lazy chunks:

```bash
mix live_islands.verify_install --full
```

For production builds, set `build.manifest: true` in `assets/vite.config.*`. The verifier checks `priv/static/assets/.vite/manifest.json` and confirms that Vite recorded dynamic island chunk entries.

## LiveView Pages

Different LiveViews already behave like different pages. With async registries, a LiveView only loads the island chunks that appear in its rendered DOM.

This keeps the architecture close to Astro:

- LiveView renders the page shell and stable HTML.
- Islands opt into interactivity explicitly.
- Component JavaScript is loaded at the island boundary, not at the whole-page boundary.
- Heavy islands can be delayed without blocking lighter islands on the same page.

## SSR

SSR and lazy hydration work together. When `ssr={true}` or `v-ssr={true}`, LiveIslands can render initial HTML on the server and hydrate it later according to the `client` strategy.

Use `client={:none}` only when the server-rendered island should stay static.

## Server-Only Islands

Use `<.react_server>` and `<.vue_server>` when a component should render through SSR but never hydrate:

```heex
<.react_server name="MarketingCard" title={@title} />
<.vue_server v-component="LegalNotice" body={@body} />
```

Server-only islands do not attach a LiveView hook and do not use `phx-update="ignore"`, so LiveView can replace their HTML on future renders. This is closer to Nuxt/Astro server islands than to a `client={:none}` hydrated island shell.

The example app includes `/server-only` as a zero-JS proof page. Its e2e test
and benchmark assertions verify that the React and Vue server-only islands render
HTML, emit no hydration or prefetch events, and do not load their React/Vue
client component chunks. The Phoenix root layout may still load the normal app
entry; the guarantee is that these islands themselves do not pull client
framework work into the route.

Deferred server islands go one step further: they render fallback HTML in the
initial response, then fetch final SSR HTML through `LiveIslands.Deferred`.
Use them when a server-only island is useful but should not block the page shell:

```heex
<.react_server name="SlowReport" defer={true}>
  <:fallback>Loading report...</:fallback>
</.react_server>
```

See [the SSR guide](ssr.md#deferred-server-islands) for the router endpoint and
cache-control setup.

## Diagnostics

When a component cannot be found or loaded, LiveIslands reports the framework, component name, and known registry entries when available. Unknown `client` strategies are warned in the browser console and fall back to `load`.
