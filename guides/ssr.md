# Server Side Rendering (SSR)

_Disclaimer_ SSR for React is not a simple topic and there is a lot of issue than can arise depending on what React components you are using. It also consume more ressource since a nodejs worker is needed for the rendering. This is a simple implementation that works for the components and library I have tested.

## Project setup

⚠️ **Warning:** Server-side rendering (SSR) requires a Node.js worker. With a `pool_size` of 1 and the Phoenix app, you need at least **512MiB** of memory. Otherwise, the instance may experience **out-of-memory (OOM)** errors or severe slowness.

SSR requires Node.js to render the javascript on server side. Add `nodejs` to your mix file.

```elixir
defp deps do
  [
    {:nodejs, "~> 3.1"},
    ...
  ]
end
```

Add NodeJs.Supervisor to your `application.ex`

```elixir
def start(_type, _args) do
  children = [
    ...
    {NodeJS.Supervisor, [path: LiveIslands.SSR.NodeJS.server_path(), pool_size: 4]},
  ]
end
```

Add a config entry to your `config/prod.exs`

```elixir
config :live_islands,
  ssr_module: LiveIslands.SSR.NodeJS,
  ssr: true
```

## Deferred server islands

Use deferred server islands when a server-only component is useful, but should
not block the initial page response. The initial HTML contains your fallback;
the final island HTML is fetched from a signed endpoint and inserted as static
HTML without attaching a LiveView hook. The deferred wrapper uses
`phx-update="ignore"` so LiveView reconnects do not replace the fetched HTML or
trigger duplicate deferred requests.

Configure and mount the endpoint:

```elixir
config :live_islands,
  ssr_module: LiveIslands.SSR.NodeJS,
  ssr: true,
  deferred_endpoint: MyAppWeb.Endpoint
```

```elixir
scope "/" do
  pipe_through :browser

  forward "/live-islands/deferred", LiveIslands.Deferred,
    endpoint: MyAppWeb.Endpoint
end
```

Then mark a server-only island as deferred:

```heex
<.react_server
  id="slow-report"
  name="SlowReport"
  report={@report}
  defer={true}
  defer_timeout={5000}
  defer_cache_control="public, max-age=60"
>
  <:fallback>
    <div>Loading report...</div>
  </:fallback>
</.react_server>
```

The browser runtime dispatches `live-islands:deferred:start`,
`live-islands:deferred:load`, and `live-islands:deferred:error`, which makes the
behavior measurable in Playwright and the built-in benchmark suite.

For complete deployment follow the [SSR deployment guide](/guides/deployment.md#with-ssr)
