# LiveIslands

React and Vue component islands inside Phoenix LiveView.

LiveIslands is the maintained fork of `live_react` that is being refactored into a framework-neutral island layer. The package keeps the existing React integration available while adding a Vue adapter based on the `live_vue` capability model.

## Features

- React and Vue component entrypoints: `LiveIslands.react/1` and `LiveIslands.vue/1`
- Shared prop encoding, compact patch serialization, LiveStream patches, and event handler metadata
- React hooks for LiveView events, event replies, navigation, connection state, forms, and uploads
- Vue composables ported from LiveVue, including events, navigation, forms, uploads, connection state, and slot injection
- Vite and NodeJS SSR adapters under the `LiveIslands.SSR` namespace
- Compatibility modules for existing `LiveReact` usage during migration

## Package Exports

```js
import { getHooks } from "live_islands/react";
import { getHooks as getVueHooks, createLiveVue } from "live_islands/vue";
import { getIslandHooks } from "live_islands";
```

The root export can combine both frameworks:

```js
const hooks = getIslandHooks({
  react: reactComponents,
  vue: createLiveVue({ resolve: vueResolver }),
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

<.vue v-component="UserPanel" user={@user} v-on:save={JS.push("save")} />
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
```

The legacy `LiveReact` modules remain in this fork so existing React code can migrate incrementally.

## Credits

LiveIslands builds on the work from:

- [mrdotb/live_react](https://github.com/mrdotb/live_react)
- [Valian/live_vue](https://github.com/Valian/live_vue)
