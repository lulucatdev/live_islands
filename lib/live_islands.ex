defmodule LiveIslands do
  @moduledoc """
  Phoenix LiveView component islands for React and Vue.

  `LiveIslands.react/1` and `LiveIslands.vue/1` share the same encoding, diffing,
  stream patching, event handler metadata, slot encoding, and SSR dispatch.
  """

  use Phoenix.Component
  import Phoenix.HTML

  alias LiveIslands.Encoder
  alias LiveIslands.Patch
  alias LiveIslands.Slots
  alias LiveIslands.SSR
  alias Phoenix.LiveView
  alias Phoenix.LiveView.LiveStream

  @react_special_keys ~w(id class ssr diff name socket __changed__ __given__)a
  @vue_special_keys [
    :id,
    :class,
    :"v-ssr",
    :"v-diff",
    :"v-component",
    :"v-socket",
    :"v-inject",
    :__changed__,
    :__given__
  ]

  @doc false
  defmacro __using__(_opts) do
    quote do
      import LiveIslands
    end
  end

  @doc """
  Renders a React island.
  """
  def react(assigns) do
    render_island(assigns, %{
      framework: :react,
      hook: "ReactHook",
      component_key: :name,
      socket_key: :socket,
      ssr_key: :ssr,
      diff_key: :diff,
      counter_key: :live_islands_react_counter,
      special_keys: @react_special_keys,
      require_component: true,
      inject?: false
    })
  end

  @doc """
  Renders a Vue island.

  Vue-specific attributes follow LiveVue's naming:

    * `v-component` selects the component.
    * `v-socket` passes the LiveView socket.
    * `v-ssr` and `v-diff` control SSR and prop diffing.
    * `v-on:*` attaches LiveView JS event handlers.
    * `v-inject` and `v-inject:*` render the island into another Vue island slot.
  """
  def vue(assigns) do
    render_island(assigns, %{
      framework: :vue,
      hook: "VueHook",
      component_key: :"v-component",
      socket_key: :"v-socket",
      ssr_key: :"v-ssr",
      diff_key: :"v-diff",
      counter_key: :live_islands_vue_counter,
      special_keys: @vue_special_keys,
      require_component: false,
      inject?: true
    })
  end

  defp render_island(assigns, config) do
    init = Map.get(assigns, :__changed__) == nil
    socket = Map.get(assigns, config.socket_key)
    dead = socket == nil or not LiveView.connected?(socket)
    use_diff = Map.get(assigns, config.diff_key, diff_default())
    use_streams_diff = Enum.any?(assigns, fn {_key, value} -> match?(%LiveStream{}, value) end)
    component_name = Map.get(assigns, config.component_key)

    render_ssr? =
      init and dead and Map.get(assigns, config.ssr_key, ssr_default()) and component_name

    {inject_target, inject_slot} = inject_config(assigns, config)

    base_assigns =
      if use_diff do
        Enum.filter(assigns, fn {key, _value} -> key_changed(assigns, key) end)
      else
        assigns
      end

    props = extract(base_assigns, :props, config)
    streams = extract(base_assigns, :streams, config)
    slots = extract(base_assigns, :slots, config)
    handlers = extract(base_assigns, :handlers, config)
    props_diff = if use_diff, do: calculate_props_diff(props, assigns), else: []

    streams_diff =
      if use_streams_diff, do: calculate_streams_diff(streams, init or dead), else: []

    assigns =
      assigns
      |> Map.put_new(:class, nil)
      |> Map.put(:__framework, config.framework)
      |> Map.put(:__hook, config.hook)
      |> Map.put(:__component_name, component_name)
      |> validate_component!(config)
      |> then(fn assigns ->
        Map.put_new_lazy(assigns, :id, fn -> id(component_name, config.counter_key) end)
      end)
      |> Map.put(:props, props)
      |> Map.put(:props_diff, Patch.serialize(props_diff))
      |> Map.put(:streams_diff, Patch.serialize(streams_diff))
      |> Map.put(:handlers, handlers)
      |> Map.put(:slots, Slots.rendered_slot_map(slots, config.framework))
      |> Map.put(:use_diff, use_diff)
      |> Map.put(:inject_target, inject_target)
      |> Map.put(:inject_slot, inject_slot)

    assigns =
      Map.put(assigns, :ssr_render, if(render_ssr?, do: ssr_render(assigns), else: nil))

    computed_changed =
      %{
        props: init or dead or not use_diff,
        slots: slots != %{},
        handlers: handlers != %{},
        ssr_render: is_map(assigns.ssr_render),
        props_diff: not init and not dead and use_diff,
        streams_diff: use_streams_diff
      }

    assigns =
      update_in(assigns.__changed__, fn
        nil -> nil
        changed -> for {key, true} <- computed_changed, into: changed, do: {key, true}
      end)

    assigns =
      assigns
      |> Map.put(
        :ssr_html,
        if(is_map(assigns.ssr_render), do: assigns.ssr_render[:html], else: nil)
      )
      |> Map.put(:ssr?, is_map(assigns.ssr_render))
      |> Map.put(:hidden_style, if(assigns.inject_target, do: "display:none", else: nil))
      |> Map.put(:no_format?, config.framework == :vue)

    ~H"""
    <div
      id={@id}
      data-framework={@__framework}
      data-name={@__component_name}
      data-props={"#{json(Encoder.encode(@props))}"}
      data-props-diff={"#{@props_diff}"}
      data-streams-diff={"#{@streams_diff}"}
      data-use-diff={@use_diff |> to_string()}
      data-handlers={"#{encode_handlers(@handlers)}"}
      data-slots={"#{@slots |> Slots.base_encode_64() |> json}"}
      data-ssr={@ssr?}
      data-inject={@inject_target}
      data-inject-slot={@inject_slot}
      phx-update="ignore"
      phx-hook={@__hook}
      phx-no-format={@no_format?}
      style={@hidden_style}
      class={@class}
    ><%= raw(@ssr_html) %></div>
    """
  end

  defp validate_component!(assigns, %{require_component: true}) do
    if is_nil(assigns.__component_name) do
      raise ArgumentError, "component name is required"
    end

    assigns
  end

  defp validate_component!(assigns, %{framework: :vue}) do
    if is_nil(assigns.__component_name) and is_nil(assigns[:id]) do
      raise ArgumentError, "<.vue> without v-component requires an explicit id"
    end

    assigns
  end

  defp validate_component!(assigns, _config), do: assigns

  defp ssr_default, do: Application.get_env(:live_islands, :ssr, true)
  defp diff_default, do: Application.get_env(:live_islands, :enable_props_diff, true)

  defp calculate_props_diff(props, %{__changed__: changed}) do
    props
    |> Enum.flat_map(fn {key, new_value} ->
      case changed[key] do
        nil ->
          []

        true ->
          [%{op: "replace", path: "/#{key}", value: Encoder.encode(new_value)}]

        old_value ->
          Jsonpatch.diff(old_value, new_value,
            ancestor_path: "/#{key}",
            prepare_map: fn
              struct when is_struct(struct) -> Encoder.encode(struct)
              rest -> rest
            end,
            object_hash: &object_hash/1
          )
      end
    end)
    |> then(fn diff -> [%{op: "test", path: "", value: :rand.uniform(10_000_000)} | diff] end)
  end

  defp calculate_streams_diff(streams, true) do
    init =
      Enum.map(streams, fn {key, _stream} -> %{op: "replace", path: "/#{key}", value: []} end)

    diffs = Enum.flat_map(streams, fn {key, stream} -> generate_stream_patches(key, stream) end)

    init ++ diffs
  end

  defp calculate_streams_diff(streams, false) do
    streams
    |> Enum.flat_map(fn {key, stream} -> generate_stream_patches(key, stream) end)
    |> then(fn diff -> [%{op: "test", path: "", value: :rand.uniform(10_000_000)} | diff] end)
  end

  defp generate_stream_patches(stream_name, %LiveStream{} = stream) do
    patches = []

    patches =
      if stream.reset?,
        do: [%{op: "replace", path: "/#{stream_name}", value: []} | patches],
        else: patches

    patches =
      Enum.reduce(stream.deletes, patches, fn dom_id, patches ->
        [%{op: "remove", path: "/#{stream_name}/$$#{dom_id}"} | patches]
      end)

    stream.inserts
    |> Enum.reverse()
    |> Enum.reduce(patches, fn
      {dom_id, at, item, limit, update_only}, patches ->
        insert_stream_patch(stream_name, dom_id, at, item, limit, update_only, patches)

      {dom_id, at, item, limit}, patches ->
        insert_stream_patch(stream_name, dom_id, at, item, limit, false, patches)
    end)
    |> Enum.reverse()
  end

  defp insert_stream_patch(stream_name, dom_id, at, item, limit, update_only, patches) do
    item = Map.put(Encoder.encode(item), :__dom_id, dom_id)

    patches =
      if update_only,
        do: [%{op: "replace", path: "/#{stream_name}/$$#{dom_id}", value: item} | patches],
        else: [
          %{op: "upsert", path: "/#{stream_name}/#{if(at == -1, do: "-", else: at)}", value: item}
          | patches
        ]

    if limit,
      do: [%{op: "limit", path: "/#{stream_name}", value: limit} | patches],
      else: patches
  end

  defp object_hash(%{id: id}), do: id
  defp object_hash(_value), do: nil

  defp extract(assigns, type, config) do
    Enum.reduce(assigns, %{}, fn {key, value}, acc ->
      case normalize_key(key, value, config) do
        ^type -> Map.put(acc, key, value)
        {^type, normalized_key} -> Map.put(acc, normalized_key, value)
        _ -> acc
      end
    end)
  end

  defp normalize_key(key, value, config) do
    cond do
      key in config.special_keys ->
        :special

      match?([%{__slot__: _}], value) ->
        :slots

      is_atom(key) ->
        key |> Atom.to_string() |> normalize_key(value, config)

      String.starts_with?(key, "v-inject:") ->
        :special

      String.starts_with?(key, "on:") ->
        {:handlers, String.replace_prefix(key, "on:", "")}

      String.starts_with?(key, "v-on:") ->
        {:handlers, String.replace_prefix(key, "v-on:", "")}

      match?(%LiveStream{}, value) ->
        :streams

      true ->
        :props
    end
  end

  defp key_changed(%{__changed__: nil}, _key), do: true
  defp key_changed(%{__changed__: changed}, key), do: changed[key] != nil

  defp ssr_render(assigns) do
    SSR.render(
      assigns.__framework,
      assigns.__component_name,
      Encoder.encode(assigns.props),
      assigns.slots
    )
  rescue
    SSR.NotConfigured ->
      nil
  end

  defp inject_config(_assigns, %{inject?: false}), do: {nil, nil}

  defp inject_config(assigns, %{inject?: true}) do
    case Map.get(assigns, :"v-inject") do
      nil ->
        find_named_inject(assigns)

      false ->
        {nil, nil}

      target when is_binary(target) ->
        {target, nil}

      _ ->
        raise ArgumentError,
              ~s(v-inject requires a target component id, for example v-inject="vue-layout")
    end
  end

  defp find_named_inject(assigns) do
    Enum.find_value(assigns, {nil, nil}, fn
      {key, value} when is_atom(key) ->
        case Atom.to_string(key) do
          "v-inject:" <> slot when is_binary(value) ->
            {value, slot}

          "v-inject:" <> _slot when value in [nil, false] ->
            nil

          "v-inject:" <> slot ->
            raise ArgumentError,
                  ~s(v-inject:#{slot} requires a target component id, for example v-inject:#{slot}="vue-layout")

          _ ->
            nil
        end

      _ ->
        nil
    end)
  end

  defp encode_handlers(handlers) do
    handlers
    |> Map.new(fn {key, %{ops: ops}} -> {key, json(ops)} end)
    |> json()
  end

  defp json(data), do: Jason.encode!(data, escape: :html_safe)

  defp id(nil, counter_key), do: id("island", counter_key)

  defp id(name, counter_key) do
    number = Process.get(counter_key, 1)
    Process.put(counter_key, number + 1)
    "#{name}-#{number}"
  end
end
