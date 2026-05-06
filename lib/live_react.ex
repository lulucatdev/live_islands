defmodule LiveReact do
  @moduledoc """
  See README.md for installation instructions and examples.
  """

  use Phoenix.Component
  import Phoenix.HTML

  alias LiveReact.Encoder
  alias LiveReact.Patch
  alias LiveReact.Slots
  alias LiveReact.SSR
  alias Phoenix.LiveView
  alias Phoenix.LiveView.LiveStream

  require Logger

  @ssr_default Application.compile_env(:live_react, :ssr, true)
  @diff_default Application.compile_env(:live_react, :enable_props_diff, true)

  @doc """
  Render a React component.
  """
  def react(assigns) do
    init = assigns.__changed__ == nil
    dead = assigns[:socket] == nil or not LiveView.connected?(assigns[:socket])
    use_diff = Map.get(assigns, :diff, @diff_default)
    use_streams_diff = Enum.any?(assigns, fn {_key, value} -> match?(%LiveStream{}, value) end)
    render_ssr? = init and dead and Map.get(assigns, :ssr, @ssr_default)
    component_name = Map.get(assigns, :name)

    base_assigns =
      if use_diff do
        Enum.filter(assigns, fn {key, _value} -> key_changed(assigns, key) end)
      else
        assigns
      end

    props = extract(base_assigns, :props)
    streams = extract(base_assigns, :streams)
    slots = extract(base_assigns, :slots)
    handlers = extract(base_assigns, :handlers)
    props_diff = if use_diff, do: calculate_props_diff(props, assigns), else: []

    streams_diff =
      if use_streams_diff, do: calculate_streams_diff(streams, init or dead), else: []

    assigns =
      assigns
      |> Map.put_new(:class, nil)
      |> Map.put_new_lazy(:id, fn -> id(component_name) end)
      |> Map.put(:__component_name, component_name)
      |> Map.put(:props, props)
      |> Map.put(:props_diff, Patch.serialize(props_diff))
      |> Map.put(:streams_diff, Patch.serialize(streams_diff))
      |> Map.put(:handlers, handlers)
      |> Map.put(:slots, Slots.rendered_slot_map(slots))
      |> Map.put(:use_diff, use_diff)

    assigns = Map.put(assigns, :ssr_render, if(render_ssr?, do: ssr_render(assigns), else: nil))

    computed_changed =
      %{
        props: init or dead or not use_diff,
        slots: slots != %{},
        handlers: handlers != %{},
        ssr_render: render_ssr?,
        props_diff: not init and not dead and use_diff,
        streams_diff: use_streams_diff
      }

    assigns =
      update_in(assigns.__changed__, fn
        nil -> nil
        changed -> for {k, true} <- computed_changed, into: changed, do: {k, true}
      end)

    # It is important not to add extra line breaks inside the div because they
    # alter React hydration.
    ~H"""
    <div
      id={@id}
      data-name={@__component_name}
      data-props={"#{json(Encoder.encode(@props))}"}
      data-props-diff={"#{@props_diff}"}
      data-streams-diff={"#{@streams_diff}"}
      data-use-diff={@use_diff |> to_string()}
      data-handlers={"#{encode_handlers(@handlers)}"}
      data-slots={"#{@slots |> Slots.base_encode_64() |> json}"}
      data-ssr={is_map(@ssr_render)}
      phx-update="ignore"
      phx-hook="ReactHook"
      class={@class}
    ><%= raw(@ssr_render[:html]) %></div>
    """
  end

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

  defp extract(assigns, type) do
    Enum.reduce(assigns, %{}, fn {key, value}, acc ->
      case normalize_key(key, value) do
        ^type -> Map.put(acc, key, value)
        {^type, normalized_key} -> Map.put(acc, normalized_key, value)
        _ -> acc
      end
    end)
  end

  defp normalize_key(key, _val)
       when key in ~w(id class ssr diff name socket __changed__ __given__)a,
       do: :special

  defp normalize_key(_key, [%{__slot__: _}]), do: :slots
  defp normalize_key(key, val) when is_atom(key), do: key |> to_string() |> normalize_key(val)
  defp normalize_key("on:" <> key, _val), do: {:handlers, key}
  defp normalize_key("v-on:" <> key, _val), do: {:handlers, key}
  defp normalize_key(_key, %LiveStream{}), do: :streams
  defp normalize_key(_key, _val), do: :props

  defp key_changed(%{__changed__: nil}, _key), do: true
  defp key_changed(%{__changed__: changed}, key), do: changed[key] != nil

  defp ssr_render(assigns) do
    try do
      name = Map.get(assigns, :name)

      SSR.render(name, Encoder.encode(assigns.props), assigns.slots)
    rescue
      SSR.NotConfigured ->
        nil
    end
  end

  defp encode_handlers(handlers) do
    handlers
    |> Map.new(fn {key, %{ops: ops}} -> {key, json(ops)} end)
    |> json()
  end

  defp json(data), do: Jason.encode!(data, escape: :html_safe)

  defp id(name) do
    number = Process.get(:live_react_counter, 1)
    Process.put(:live_react_counter, number + 1)
    "#{name}-#{number}"
  end
end
