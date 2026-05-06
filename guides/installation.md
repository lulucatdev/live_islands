# Installation

LiveIslands replaces `hex esbuild` with [Vite](https://vite.dev/) for both client side code and SSR to achieve a better development experience. Why ?

- Vite provides a best-in-class Hot-Reload functionality and offers [many benefits](https://vitejs.dev/guide/why#why-vite) not present in esbuild
- `hex esbuild` package doesn't support plugins, while it's possible to do ssr with `hex esbuild` (check [v0.2.0-rc-0](https://github.com/lulucatdev/live_islands/tree/v0.2.0-rc.0)) the SSR in development is broken.
- React, Vue, and SSR integration are easier to keep in one Vite pipeline

In production, we'll use [elixir-nodejs](https://github.com/revelrylabs/elixir-nodejs) for SSR. If you don't need SSR, you can disable it with one line of code. TypeScript will be supported as well.

## Steps

0. install nodejs (I recommend [mise](https://mise.jdx.dev/))

1. Add `live_islands` to your list of dependencies in `mix.exs` and run `mix deps.get`

```elixir
def deps do
  [
    {:live_islands, git: "https://github.com/lulucatdev/live_islands"},
    {:nodejs, "~> 3.1.2"} # if you want to use SSR in production
  ]
end
```

2. Add a config entry to your `config/dev.exs`

```elixir
config :live_islands,
  vite_host: "http://localhost:5173",
  ssr_module: LiveIslands.SSR.ViteJS,
  ssr: true
```

3. Add a config entry to your `config/prod.exs`

```elixir
config :live_islands,
  ssr_module: LiveIslands.SSR.NodeJS,
  ssr: true # or false if you don't want SSR in production
```

4. Add `import LiveIslands` in `html_helpers/0` inside `/lib/<app_name>_web.ex` like so:

```elixir
# /lib/<app_name>_web.ex

defp html_helpers do
  quote do

    # ...

    import LiveIslands # <-- Add this line

    # ...

  end
end
```

5. LiveIslands includes an installer task for the required asset files and common Phoenix configuration. It preserves files that already exist in your project and applies conservative edits to `assets/js/app.js`, `config/config.exs`, `config/dev.exs`, and `config/prod.exs`.

It will create:

- `package.json`
- vite, typescript and postcss configs
- server entrypoint
- React and Vue component roots

6. Run the following in your terminal

```bash
mix deps.get
mix live_islands.install
npm install --prefix assets
```

7. Confirm that your `assets/js/app.js` file contains the LiveIslands hooks

```javascript
...
import topbar from "topbar" // instead of ../vendor/topbar
import { getIslandHooks } from "live_islands";
import reactComponents from "../react-components";
import vueComponents from "../vue-components";
import "../css/app.css" // the css file is handled by vite

const hooks = getIslandHooks({ react: reactComponents, vue: vueComponents });

...

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: hooks, // <- pass the hooks
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
});
...
```

7. For tailwind support, make some addition to `content` in the `assets/tailwind.config.js` file

```javascript
content: [
  ...
    "./react-components/**/*.jsx", // <- if you are using jsx
    "./react-components/**/*.tsx", // <- if you are using tsx
    "./vue-components/**/*.vue"
],

```

8. Let's update `root.html.heex` to use Vite files in development. There's a handy wrapper for it.

```html
<LiveIslands.Reload.vite_assets assets={["/js/app.js", "/css/app.css"]}>
  <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
  <script type="module" phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
  </script>
</LiveIslands.Reload.vite_assets>
```

9. Update `mix.exs` aliases and remove `tailwind` and `esbuild` packages

```elixir
defp aliases do
[
  setup: ["deps.get", "assets.setup", "assets.build"],
  "assets.setup": ["cmd --cd assets npm install"],
  "assets.build": [
    "cmd --cd assets npm run build",
    "cmd --cd assets npm run build-server"
  ],
  "assets.deploy": [
    "cmd --cd assets npm run build",
    "cmd --cd assets npm run build-server",
    "phx.digest"
  ]
]
end

defp deps do
  [
    # remove these lines, we don't need esbuild or tailwind here anymore
    # {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
    # {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
  ]
end
```

10. Remove esbuild and tailwind config from `config/config.exs`

11. Update watchers in `config/dev.exs` to look like this

```elixir
config :my_app, MyAppWeb.Endpoint,
  # ...
  watchers: [
    npm: ["run", "dev", cd: Path.expand("../assets", __DIR__)]
  ]
```

12. To make SSR working with `LiveIslands.SSR.NodeJS` in production, you have to add this entry to your `application.ex` supervision tree to run the NodeJS server

If you don't want SSR in production, you can skip this step.

```elixir
children = [
  ...
  {NodeJS.Supervisor, [path: LiveIslands.SSR.NodeJS.server_path(), pool_size: 4]},
  # note Adjust the pool_size depending of the machine
]
```

13. Confirm everything is working by rendering the default React and Vue components anywhere in your Dead or Live Views

```elixir
<.react name="Simple" />
<.vue v-component="status" message="Vue island ready" />
```

You can also use the built-in Link component for LiveView navigation:

```elixir
<!-- Use Link component directly in templates -->
<.react name="Link" href="/some-page">External Link</.react>
<.react name="Link" patch="/current-liveview?tab=new">Patch Link</.react>
<.react name="Link" navigate="/other-liveview">Navigate Link</.react>

<!-- Or import it in your React components -->
```

```javascript
import { Link } from "live_islands/react";

function MyComponent() {
  return (
    <div>
      <Link href="/external">Traditional Link</Link>
      <Link patch="/same-lv?param=value">Patch Current LiveView</Link>
      <Link navigate="/other-lv">Navigate to Other LiveView</Link>
      <Link navigate="/replace" replace={true}>
        Replace History
      </Link>
    </div>
  );
}
```

14. (Optional) enable [stateful hot reload](https://twitter.com/jskalc/status/1788308446007132509) of Phoenix LiveViews. Adjust your `dev.exs` to add the `notify` section and remove `live|components` from patterns.

```elixir
# Watch static and templates for browser reloading.
config :my_app, MyAppWeb.Endpoint,
  live_reload: [
    notify: [
      live_view: [
        ~r"lib/my_app_web/core_components.ex$",
        ~r"lib/my_app_web/(live|components)/.*(ex|heex)$"
      ]
    ],
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/my_app_web/controllers/.*(ex|heex)$"
    ]
  ]
```

At this point the Phoenix application can render React and Vue components through LiveIslands.

## Adjusting your own package.json

Install these packages

```bash
cd assets

# vite
npm install -D vite @vitejs/plugin-react @vitejs/plugin-vue

# tailwind
npm install -D @tailwindcss/forms @tailwindcss/postcss @tailwindcss/vite

# typescript
npm install -D typescript @types/react @types/react-dom

# runtime dependencies
npm install --save react react-dom vue topbar ../deps/live_islands ../deps/phoenix ../deps/phoenix_html ../deps/phoenix_live_view

# remove topbar from vendor, since we'll use it from node_modules
rm vendor/topbar.js
```

and add these scripts used by watcher and `mix assets.build` command

```json
{
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite --host -l warn",
    "build": "tsc && vite build",
    "build-server": "tsc && vite build --ssr js/server.js --out-dir ../priv/island-components --minify esbuild && echo '{\"type\": \"module\" } ' > ../priv/island-components/package.json"
  }
}
```
