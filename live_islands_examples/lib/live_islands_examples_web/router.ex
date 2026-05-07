defmodule LiveIslandsExamplesWeb.Router do
  use LiveIslandsExamplesWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LiveIslandsExamplesWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # pipeline :api do
  #   plug :accepts, ["json"]
  # end

  scope "/" do
    pipe_through :browser

    forward "/live-islands/deferred", LiveIslands.Deferred,
      endpoint: LiveIslandsExamplesWeb.Endpoint
  end

  scope "/", LiveIslandsExamplesWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/lazy", PageController, :lazy
    get "/simple", PageController, :simple
    get "/simple-props", PageController, :simple_props
    get "/typescript", PageController, :typescript
    get "/server-only", PageController, :server_only
    get "/profile/react-only", PageController, :profile_react_only
    get "/profile/vue-only", PageController, :profile_vue_only
    get "/profile/mixed", PageController, :profile_mixed

    live "/live-counter", LiveCounter
    live "/context", LiveContext
    live "/log-list", LiveLogList
    live "/flash-sonner", LiveFlashSonner
    live "/ssr", LiveSSR
    live "/hybrid-form", LiveHybridForm
    live "/slot", LiveSlot
    live "/link-demo", LiveLinkDemo
    live "/link-usage", LiveLinkUsage
    live "/capabilities", LiveCapabilities
    live "/benchmarks", LiveBenchmarks
    live "/todo", LiveTodoApp
  end

  # Other scopes may use custom stacks.
  # scope "/api", LiveIslandsExamplesWeb do
  #   pipe_through :api
  # end
end
