# Installation

LiveIslands installs a Vite asset pipeline for Phoenix applications and uses it for both browser assets and SSR bundles. The installed default is:

- Vite for development and production asset builds
- Tailwind CSS through npm and `@tailwindcss/vite`
- React and Vue component roots in the same Phoenix project
- No daisyUI integration

Phoenix 1.8 new applications ship with Tailwind CSS 4 and daisyUI through Mix-managed `tailwind` and `esbuild` assets. `mix live_islands.install` intentionally replaces that stack with npm + Vite so React and Vue islands, Tailwind CSS, and SSR share one JavaScript toolchain.

## Steps

Install Node.js, then add LiveIslands to `mix.exs`:

```elixir
def deps do
  [
    {:live_islands, git: "https://github.com/lulucatdev/live_islands"}
  ]
end
```

Run the installer:

```bash
mix deps.get
mix live_islands.install
npm install --prefix assets
```

The installer creates the Vite asset files when they are missing:

- `assets/package.json`
- `assets/vite.config.js`
- `assets/postcss.config.js`
- `assets/tsconfig.json`
- `assets/js/server.js`
- `assets/react-components/*`
- `assets/vue-components/*`

It also patches common Phoenix files:

- removes Mix `:esbuild` and `:tailwind` dependencies
- adds `{:nodejs, "~> 3.1"}` for production SSR support
- rewrites `assets.setup`, `assets.build`, and `assets.deploy` aliases to npm scripts
- rewrites the development watcher to `npm run dev`
- removes Phoenix 1.8 daisyUI CSS plugin blocks and generated daisyUI vendor files
- keeps Tailwind CSS sources for Phoenix code, app JS/CSS, React components, and Vue components
- wires `assets/js/app.js` to `getIslandHooks({react, vue})`
- preserves Phoenix colocated hooks when present
- imports `LiveIslands` in web helpers
- wraps root layout asset tags with `LiveIslands.Reload.vite_assets`
- configures Vite SSR in development and NodeJS SSR in production

## Verify

Build the installed assets:

```bash
npm run build --prefix assets
npm run build-server --prefix assets
mix compile
```

Render one React component and one Vue component from a template or LiveView:

```heex
<.react name="Simple" />
<.vue v-component="status" message="Vue island ready" />
```

## SSR

SSR is enabled by default:

```elixir
config :live_islands,
  ssr: true,
  enable_props_diff: true
```

Development uses the Vite dev server:

```elixir
config :live_islands,
  vite_host: System.get_env("VITE_HOST") || "http://localhost:5173",
  ssr_module: LiveIslands.SSR.ViteJS
```

Production uses the NodeJS SSR bundle:

```elixir
config :live_islands,
  ssr_module: LiveIslands.SSR.NodeJS
```

For production SSR, add the NodeJS supervisor to your application supervision tree:

```elixir
children = [
  {NodeJS.Supervisor, [path: LiveIslands.SSR.NodeJS.server_path(), pool_size: 4]}
]
```

Adjust `pool_size` for the deployment machine. If you do not want SSR in production, set `ssr: false` in production config and omit the supervisor.
