# Lazy Islands

LiveIslands supports Astro-style selective hydration for Phoenix LiveView.

The page still arrives as LiveView-rendered HTML. Each island then decides when to load its component module and hydrate:

```heex
<.react name="Chart" client={:visible} ssr={true} />
<.vue v-component="Filters" client={:idle} v-ssr={true} />
<.react name="WideMap" client={{:media, "(min-width: 1024px)"}} />
<.react name="StaticCard" client={:none} ssr={true} />
```

## Client Strategies

- `:load` hydrates as soon as the LiveView hook mounts. This is the default.
- `:idle` waits for `requestIdleCallback`, with a timeout fallback.
- `:visible` waits until the island enters the viewport.
- `{:media, query}` waits until `window.matchMedia(query)` matches.
- `:none` never hydrates. Use this only with SSR when you want static HTML.

These strategies are per-island, so a page can hydrate a small navigation island immediately and defer a heavy chart until it is visible.

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
});
```

Vue:

```js
import { createVueIsland } from "live_islands/vue";

const modules = import.meta.glob("./**/*.vue");

export default createVueIsland({
  resolve: (name) => modules[`./${name}.vue`]?.(),
});
```

You can still pass a plain synchronous component map. Async registries are the recommended default for larger apps.

Run the full installer verifier after wiring async registries. It checks that the client build actually emitted lazy chunks:

```bash
mix live_islands.verify_install --full
```

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

## Diagnostics

When a component cannot be found or loaded, LiveIslands reports the framework, component name, and known registry entries when available. Unknown `client` strategies are warned in the browser console and fall back to `load`.
