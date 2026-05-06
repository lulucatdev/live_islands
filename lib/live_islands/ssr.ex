defmodule LiveIslands.SSR.NotConfigured do
  @moduledoc false

  defexception [:message]
end

defmodule LiveIslands.SSR do
  require Logger

  @moduledoc """
  A behaviour for rendering LiveIslands components server-side.

  To define a custom renderer, change the application config in `config.exs`:

      config :live_islands, ssr_module: MyCustomSSRModule

  Exposes a telemetry span for each render under key `[:live_islands, :ssr]`
  """

  @type component_name :: String.t()
  @type props :: %{optional(String.t() | atom) => any}
  @type slots :: %{optional(String.t()) => any}

  @typedoc """
  A render response which should have shape

  %{
    html: string,
  }
  """
  @type render_response :: %{optional(String.t() | atom) => any}

  @type framework :: :react | :vue | atom

  @callback render(component_name, props, slots) :: render_response | no_return
  @callback render(framework, component_name, props, slots) :: render_response | no_return
  @optional_callbacks render: 3, render: 4

  @spec render(component_name, props, slots) :: render_response | no_return
  def render(name, props, slots), do: render(:react, name, props, slots)

  @spec render(framework, component_name, props, slots) :: render_response | no_return
  def render(framework, name, props, slots) do
    case ssr_module(framework) do
      nil ->
        %{preloadLinks: "", html: ""}

      mod ->
        meta = %{framework: framework, component: name, props: props, slots: slots}

        body =
          :telemetry.span([:live_islands, framework, :ssr], meta, fn ->
            {call_renderer(mod, framework, name, props, slots), meta}
          end)

        with body when is_binary(body) <- body do
          case String.split(body, "<!-- preload -->", parts: 2) do
            [links, html] -> %{preloadLinks: links, html: html}
            [body] -> %{preloadLinks: "", html: body}
          end
        end
    end
  end

  defp ssr_module(framework) do
    Application.get_env(:live_islands, :"#{framework}_ssr_module") ||
      Application.get_env(:live_islands, :ssr_module)
  end

  defp call_renderer(mod, framework, name, props, slots) do
    Code.ensure_loaded!(mod)

    cond do
      function_exported?(mod, :render, 4) -> mod.render(framework, name, props, slots)
      function_exported?(mod, :render, 3) -> mod.render(name, props, slots)
      true -> raise ArgumentError, "#{inspect(mod)} must export render/3 or render/4"
    end
  end
end
