# LiveIslands

Astro-style React and Vue component islands inside Phoenix LiveView.

LiveIslands is a framework-neutral island layer for rendering client components from Phoenix LiveView. It exposes first-class React and Vue adapters under a single Elixir package and a single JavaScript package.

LiveIslands is an independent project. It began as an extraction and redesign informed by the excellent `live_react` and `live_vue` projects, then moved to a unified React/Vue runtime with Vite, Tailwind, SSR, lazy hydration, and an agent-verifiable installation flow.

## Features

- React and Vue component entrypoints: `LiveIslands.react/1` and `LiveIslands.vue/1`
- Shared prop encoding, compact patch serialization, LiveStream patches, and event handler metadata
- React hooks for LiveView events, event replies, navigation, connection state, forms, and uploads
- Vue composables for events, navigation, forms, uploads, connection state, and slot injection
- Astro-style async islands with `client={:load | :idle | :visible | {:media, query}}`
- Vite and NodeJS SSR adapters under the `LiveIslands.SSR` namespace

## Package Exports

```js
import {
  createReactIsland,
  getHooks as getReactHooks,
} from "live_islands/react";
import { getHooks as getVueHooks, createVueIsland } from "live_islands/vue";
import { getIslandHooks } from "live_islands";
```

The root export can combine both frameworks:

```js
const modules = import.meta.glob("./react-components/**/*.jsx");

const hooks = getIslandHooks({
  react: createReactIsland({
    availableComponents: modules,
    resolve: (name) => modules[`./react-components/${name}.jsx`]?.(),
  }),
  vue: createVueIsland({ resolve: vueResolver }),
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
<.react name="DashboardCard" title={@title} />

<.vue v-component="UserPanel" client={:visible} user={@user} v-on:save={JS.push("save")} />
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

## Credits

LiveIslands is built with gratitude for the upstream projects that made the direction clear:

- [mrdotb/live_react](https://github.com/mrdotb/live_react)
- [Valian/live_vue](https://github.com/Valian/live_vue)

See [NOTICE.md](NOTICE.md) for attribution and license notes.
