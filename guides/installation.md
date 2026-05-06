# Installation

LiveIslands is installed as a Phoenix integration, not as a one-size-fits-all rewrite of the host app.

Phoenix projects differ: some use the Phoenix 1.8 Tailwind/daisyUI defaults, some already use Vite, and some have a custom design system. LiveIslands only requires the integration points below. It does not require removing daisyUI.

## Recommended Agent Flow

Use the repo skill at `skills/live-islands-install/SKILL.md` when installing through a coding agent. The skill tells the agent to inspect the target project first, preserve existing UI choices, wire only the required LiveIslands pieces, and run the verifier.

`mix live_islands.install` is optional. It only copies missing template files under `assets/`; it does not patch `mix.exs`, JavaScript, layouts, config, Tailwind, or daisyUI.

## Required Pieces

Add LiveIslands to `mix.exs`:

```elixir
def deps do
  [
    {:live_islands, git: "https://github.com/lulucatdev/live_islands"}
  ]
end
```

Wire Phoenix helpers:

```elixir
defp html_helpers do
  quote do
    import LiveIslands
  end
end
```

Install the JavaScript packages used by the Vite pipeline:

```json
{
  "dependencies": {
    "live_islands": "file:../deps/live_islands",
    "phoenix": "file:../deps/phoenix",
    "phoenix_html": "file:../deps/phoenix_html",
    "phoenix_live_view": "file:../deps/phoenix_live_view",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "vue": "^3.5.10"
  },
  "devDependencies": {
    "vite": "^6.3.3",
    "@vitejs/plugin-react": "^4.3.1",
    "@vitejs/plugin-vue": "^6.0.0",
    "@tailwindcss/vite": "^4.1.12",
    "tailwindcss": "^4.1.12",
    "typescript": "^5.6.2"
  }
}
```

Configure Vite with React, Vue, and LiveIslands plugins. If the Phoenix app imports colocated hooks from `phoenix-colocated/<app>`, add an alias to the Mix build output:

```js
import path from "path";
import react from "@vitejs/plugin-react";
import vue from "@vitejs/plugin-vue";
import liveIslandsPlugin from "live_islands/vite-plugin";
import { defineConfig } from "vite";

export default defineConfig(({ command }) => {
  const isDev = command !== "build";
  const mixEnv = process.env.MIX_ENV || "dev";

  return {
    base: isDev ? undefined : "/assets",
    plugins: [react(), vue(), liveIslandsPlugin()],
    build: {
      manifest: true,
    },
    resolve: {
      alias: {
        "phoenix-colocated": path.resolve(
          __dirname,
          `../_build/${mixEnv}/phoenix-colocated`,
        ),
      },
    },
  };
});
```

Wire `assets/js/app.js` by combining LiveIslands hooks with existing hooks:

```js
import { getIslandHooks } from "live_islands";
import reactComponents from "../react-components";
import vueComponents from "../vue-components";

const islandHooks = getIslandHooks({
  react: reactComponents,
  vue: vueComponents,
  prefetch: { scope: "page" },
});

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...existingHooks, ...islandHooks },
  params: { _csrf_token: csrfToken },
});
```

Use the Vite helper in the root layout. In development it points at the Vite
server; in production it reads the Vite manifest and emits the content-hashed
entry files so dynamic island chunks share the same module graph.

```heex
<LiveIslands.Reload.vite_assets assets={["/js/app.js", "/css/app.css"]}>
  <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
  <script type="module" phx-track-static src={~p"/assets/app.js"}>
  </script>
</LiveIslands.Reload.vite_assets>
```

Add component roots and an SSR entrypoint:

- `assets/react-components/index.{js,jsx,ts,tsx}`
- `assets/vue-components/index.{js,ts}`
- `assets/js/server.js`

Prefer async component registries for production apps:

```js
import { createReactIsland } from "live_islands/react";

const components = {
  Dashboard: () => import("./dashboard"),
  Settings: () => import("./settings"),
};

export default createReactIsland({
  availableComponents: components,
  resolve: (name) => components[name]?.(),
});
```

The optional scaffold task can copy starter versions:

```bash
mix deps.get
mix live_islands.install
```

## Tailwind and daisyUI

Keep the host app's CSS unless the user asks for a replacement.

LiveIslands needs Tailwind to scan React and Vue component directories, but daisyUI can stay:

```css
@source "../react-components";
@source "../vue-components";
```

Phoenix 1.8's default daisyUI `@plugin` and theme blocks are not a problem for LiveIslands if the Vite/Tailwind build passes.

## SSR

For SSR in development:

```elixir
config :live_islands,
  otp_app: :my_app,
  ssr: true,
  enable_props_diff: true,
  vite_host: System.get_env("VITE_HOST") || "http://localhost:5173",
  ssr_module: LiveIslands.SSR.ViteJS
```

For SSR in production:

```elixir
config :live_islands,
  otp_app: :my_app,
  ssr_module: LiveIslands.SSR.NodeJS
```

Add the NodeJS supervisor when production SSR is enabled:

```elixir
children = [
  {NodeJS.Supervisor, [path: LiveIslands.SSR.NodeJS.server_path(), pool_size: 4]}
]
```

If the project does not need SSR, set `ssr: false` and skip the server bundle and supervisor.

## Verify

Run the static integration verifier:

```bash
mix live_islands.verify_install
```

Then run the full frontend verifier. It runs the Vite client build, the SSR bundle build, and checks for emitted CSS, JavaScript, and lazy island chunks:

```bash
mix live_islands.verify_install --full
```

If node modules are not installed yet:

```bash
mix live_islands.verify_install --full --install
```

If SSR is intentionally disabled:

```bash
mix live_islands.verify_install --full --skip-ssr
```

Then run the remaining Elixir checks:

```bash
mix compile
mix test
```

Finally render one React island and one Vue island:

```heex
<.react name="Simple" client={:visible} prefetch={:idle} />
<.vue v-component="status" client={:idle} prefetch={:hover} message="Vue island ready" />
```

See `guides/lazy-islands.md` for `client={:load | :idle | :visible | :interaction | {:media, query} | :none}`, `prefetch={:load | :idle | :visible | :hover | :tap | :interaction | {:media, query} | :none}`, server-only islands, custom strategies, and component-level code splitting.
