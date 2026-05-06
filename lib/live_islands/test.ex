defmodule LiveIslands.Test do
  @moduledoc """
  Helpers for testing LiveIslands components and views.

  ## Overview

  LiveIslands testing differs from traditional Phoenix LiveView testing in how components
  are rendered and inspected:

  * In Phoenix LiveView testing, you use `Phoenix.LiveViewTest.render_component/2`
    to get the final rendered HTML
  * In LiveIslands testing, `render_component/2` returns an unrendered LiveIslands root
    element containing the Island component's configuration

  This module provides helpers to extract and inspect Island component data from the
  LiveIslands root element, including:

  * Component name and ID
  * Props passed to the component
  * Event handlers and their operations
  * Server-side rendering (SSR) status
  * Slot content
  * CSS classes

  ## Examples

      # Render a LiveIslands component and inspect its properties
      {:ok, view, _html} = live(conn, "/")
      island = LiveIslands.Test.get_island(view)

      # Basic component info
      assert island.component == "MyComponent"
      assert island.props["title"] == "Hello"

      # Event handlers
      assert island.handlers["click"] == JS.push("click")

      # SSR status and styling
      assert island.ssr == true
      assert island.class == "my-custom-class"
  """

  @compile {:no_warn_undefined, Floki}

  alias LiveIslands.Patch

  @doc """
  Extracts Island component information from a LiveView or HTML string.

  When multiple Island components are present, you can specify which one to extract using
  either the `:name` or `:id` option.

  Returns a map containing the component's configuration:
    * `:component` - The Island component name (from `v-component` attribute)
    * `:id` - The unique component identifier (auto-generated or explicitly set)
    * `:props` - The decoded props passed to the component
    * `:handlers` - Map of event handlers (`v-on:*`) and their operations
    * `:slots` - Base64 encoded slot content
    * `:ssr` - Boolean indicating if server-side rendering was performed
    * `:class` - CSS classes applied to the component root element

  ## Options
    * `:name` - Find component by name (from `v-component` attribute)
    * `:id` - Find component by ID

  ## Examples

      # From a LiveView, get first Island component
      {:ok, view, _html} = live(conn, "/")
      island = LiveIslands.Test.get_island(view)

      # Get specific component by name
      island = LiveIslands.Test.get_island(view, name: "MyComponent")

      # Get specific component by ID
      island = LiveIslands.Test.get_island(view, id: "my-component-1")
  """
  def get_island(view, opts \\ [])

  def get_island(view, opts) when is_struct(view, Phoenix.LiveViewTest.View) do
    view |> Phoenix.LiveViewTest.render() |> get_island(opts)
  end

  def get_island(html, opts) when is_binary(html) do
    if Code.ensure_loaded?(Floki) do
      island =
        html
        |> Floki.parse_document!()
        |> Floki.find(
          "[phx-hook='LiveIslandsReactHook'], [phx-hook='LiveIslandsVueHook'], [data-framework][data-name]"
        )
        |> find_component!(opts)

      %{
        props: Jason.decode!(attr(island, "data-props")),
        props_diff: decode_patch(attr(island, "data-props-diff")),
        streams_diff: decode_patch(attr(island, "data-streams-diff")),
        use_diff: attr(island, "data-use-diff") == "true",
        handlers: decode_handlers(attr(island, "data-handlers")),
        framework: attr(island, "data-framework"),
        component: attr(island, "data-name"),
        id: attr(island, "id"),
        slots: extract_base64_slots(attr(island, "data-slots")),
        client: attr(island, "data-client"),
        client_media: attr(island, "data-client-media"),
        prefetch: attr(island, "data-prefetch"),
        prefetch_media: attr(island, "data-prefetch-media"),
        ssr: attr(island, "data-ssr") == "true",
        server_only: truthy_attr?(island, "data-server-only"),
        hook: attr(island, "phx-hook"),
        phx_update: attr(island, "phx-update"),
        class: attr(island, "class")
      }
    else
      raise "Floki is not installed. Add {:floki, \">= 0.30.0\", only: :test} to your dependencies to use LiveIslands.Test"
    end
  end

  def get_react(view, opts \\ []), do: get_island(view, Keyword.put(opts, :framework, "react"))
  def get_vue(view, opts \\ []), do: get_island(view, Keyword.put(opts, :framework, "vue"))

  defp extract_base64_slots(slots) do
    slots
    |> Jason.decode!()
    |> Enum.map(fn {key, value} -> {key, Base.decode64!(value)} end)
    |> Enum.into(%{})
  end

  defp decode_patch(nil), do: []
  defp decode_patch(value), do: Patch.deserialize(value)

  defp decode_handlers(nil), do: %{}

  defp decode_handlers(value) do
    value
    |> Jason.decode!()
    |> Map.new(fn {event, ops} -> {event, Jason.decode!(ops)} end)
  end

  defp find_component!(components, opts) do
    available = Enum.map_join(components, ", ", &"#{attr(&1, "data-name")}##{attr(&1, "id")}")

    components =
      Enum.reduce(opts, components, fn
        {:id, id}, result ->
          with [] <- Enum.filter(result, &(attr(&1, "id") == id)) do
            raise "No Island component found with id=\"#{id}\". Available components: #{available}"
          end

        {:name, name}, result ->
          with [] <- Enum.filter(result, &(attr(&1, "data-name") == name)) do
            raise "No Island component found with name=\"#{name}\". Available components: #{available}"
          end

        {:framework, framework}, result ->
          with [] <- Enum.filter(result, &(attr(&1, "data-framework") == framework)) do
            raise "No Island component found with framework=\"#{framework}\". Available components: #{available}"
          end

        {key, _}, _result ->
          raise ArgumentError, "invalid keyword option for get_island/2: #{key}"
      end)

    case components do
      [island | _] ->
        island

      [] ->
        raise "No Island components found in the rendered HTML"
    end
  end

  defp attr(element, name) do
    case Floki.attribute(element, name) do
      [value] -> value
      [] -> nil
    end
  end

  defp truthy_attr?(element, name) do
    case attr(element, name) do
      nil -> false
      false -> false
      "false" -> false
      _ -> true
    end
  end
end
