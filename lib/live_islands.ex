defmodule LiveIslands do
  @moduledoc """
  Phoenix LiveView component islands for React and Vue.

  `LiveIslands.react/1` and `LiveIslands.vue/1` share the same encoding, diffing,
  stream patching, event handler metadata, slot encoding, and SSR dispatch.
  """

  use Phoenix.Component
  import Phoenix.HTML

  alias LiveIslands.Encoder
  alias LiveIslands.Deferred
  alias LiveIslands.Patch
  alias LiveIslands.Slots
  alias LiveIslands.SSR
  alias Phoenix.LiveView
  alias Phoenix.LiveView.LiveStream

  @defer_special_keys ~w(defer defer_path defer_endpoint defer_token defer_timeout defer_cache_control cache_control fallback)a
  @react_special_keys ~w(id class ssr diff name socket client client_media prefetch prefetch_media server_only __changed__ __given__)a ++
                        @defer_special_keys
  @vue_special_keys [
                      :id,
                      :class,
                      :client,
                      :client_media,
                      :prefetch,
                      :prefetch_media,
                      :server_only,
                      :"v-ssr",
                      :"v-diff",
                      :"v-component",
                      :"v-socket",
                      :"v-client",
                      :"v-client-media",
                      :"v-prefetch",
                      :"v-prefetch-media",
                      :"v-inject",
                      :__changed__,
                      :__given__
                    ] ++ @defer_special_keys

  @doc false
  defmacro __using__(_opts) do
    quote do
      import LiveIslands
    end
  end

  @doc """
  Renders a React island.

  Use `client` to control hydration timing:

    * `:load` hydrates immediately. This is the default.
    * `:idle` hydrates when the browser is idle.
    * `:visible` hydrates when the island enters the viewport.
    * `{:media, query}` hydrates when a media query matches.
    * `:none` skips client hydration for SSR-only static islands.

  Use `prefetch` to load the component module before hydration without mounting
  the island. Supported values are `:load`, `:idle`, `:visible`, `:hover`,
  `:tap`, `{:media, query}`, and `:none`.
  """
  def react(assigns) do
    render_island(assigns, %{
      framework: :react,
      hook: "LiveIslandsReactHook",
      component_key: :name,
      socket_key: :socket,
      ssr_key: :ssr,
      diff_key: :diff,
      counter_key: :live_islands_react_counter,
      special_keys: @react_special_keys,
      require_component: true,
      inject?: false,
      client_keys: [:client],
      client_media_keys: [:client_media],
      prefetch_keys: [:prefetch],
      prefetch_media_keys: [:prefetch_media]
    })
  end

  @doc """
  Renders a server-only React island.

  Server-only islands render through the configured SSR adapter, do not attach a
  LiveView hook, and do not ship island JavaScript. LiveView may replace their
  HTML on later renders because they do not use `phx-update="ignore"`.

  Pass `defer={true}` to render the fallback immediately and fetch the final SSR
  HTML from the configured deferred endpoint after the page begins loading.
  """
  def react_server(assigns) do
    assigns
    |> Map.put(:server_only, true)
    |> Map.put(:ssr, true)
    |> Map.put(:client, :none)
    |> Map.put(:prefetch, :none)
    |> react()
  end

  @doc """
  Renders a Vue island.

  Vue-specific attributes use the `v-*` convention:

    * `v-component` selects the component.
    * `v-socket` passes the LiveView socket.
    * `v-ssr` and `v-diff` control SSR and prop diffing.
    * `client` or `v-client` controls hydration timing.
    * `prefetch` or `v-prefetch` controls module prefetch timing.
    * `v-on:*` attaches LiveView JS event handlers.
    * `v-inject` and `v-inject:*` render the island into another Vue island slot.
  """
  def vue(assigns) do
    render_island(assigns, %{
      framework: :vue,
      hook: "LiveIslandsVueHook",
      component_key: :"v-component",
      socket_key: :"v-socket",
      ssr_key: :"v-ssr",
      diff_key: :"v-diff",
      counter_key: :live_islands_vue_counter,
      special_keys: @vue_special_keys,
      require_component: false,
      inject?: true,
      client_keys: [:client, :"v-client"],
      client_media_keys: [:client_media, :"v-client-media"],
      prefetch_keys: [:prefetch, :"v-prefetch"],
      prefetch_media_keys: [:prefetch_media, :"v-prefetch-media"]
    })
  end

  @doc """
  Renders a server-only Vue island.

  Server-only islands render through the configured SSR adapter, do not attach a
  LiveView hook, and do not ship island JavaScript. LiveView may replace their
  HTML on later renders because they do not use `phx-update="ignore"`.

  Pass `defer={true}` to render the fallback immediately and fetch the final SSR
  HTML from the configured deferred endpoint after the page begins loading.
  """
  def vue_server(assigns) do
    assigns
    |> Map.put(:server_only, true)
    |> Map.put(:"v-ssr", true)
    |> Map.put(:client, :none)
    |> Map.put(:prefetch, :none)
    |> vue()
  end

  defp render_island(assigns, config) do
    context = island_context(assigns, config)
    base_assigns = changed_assigns(assigns, context.use_diff)
    data = island_data(base_assigns, assigns, config, context)

    assigns =
      assigns
      |> put_island_assigns(config, context, data)
      |> put_ssr_render(context.render_ssr?)
      |> put_deferred_render(context)
      |> put_computed_changed(context, data)
      |> put_render_flags(config, context)

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
      data-client={@client}
      data-client-media={@client_media}
      data-prefetch={@prefetch}
      data-prefetch-media={@prefetch_media}
      data-ssr={@ssr?}
      data-server-only={@server_only?}
      data-deferred={@deferred?}
      data-live-islands-defer-src={@defer_src}
      data-live-islands-defer-timeout={@defer_timeout}
      data-live-islands-defer-state={@defer_state}
      data-inject={@inject_target}
      data-inject-slot={@inject_slot}
      phx-update={@phx_update}
      phx-hook={@__hook}
      phx-no-format={@no_format?}
      style={@hidden_style}
      class={@class}
    >
      <%= if @deferred? do %>
        <%= render_slot(@fallback) %>
      <% else %>
        <%= raw(@ssr_html) %>
      <% end %>
    </div>
    """
  end

  defp island_context(assigns, config) do
    init? = Map.get(assigns, :__changed__) == nil
    socket = Map.get(assigns, config.socket_key)
    dead? = socket == nil or not LiveView.connected?(socket)
    use_diff = Map.get(assigns, config.diff_key, diff_default())
    server_only? = Map.get(assigns, :server_only, false)
    component_name = Map.get(assigns, config.component_key)
    {client, client_media} = client_config(assigns, config)
    {prefetch, prefetch_media} = prefetch_config(assigns, config)
    {inject_target, inject_slot} = inject_config(assigns, config)
    deferred? = server_only? and defer?(assigns)

    %{
      init?: init?,
      dead?: dead?,
      use_diff: use_diff,
      use_streams_diff: streams_diff?(assigns),
      component_name: component_name,
      server_only?: server_only?,
      client: client,
      client_media: client_media,
      prefetch: prefetch,
      prefetch_media: prefetch_media,
      inject_target: inject_target,
      inject_slot: inject_slot,
      deferred?: deferred?,
      defer_path: Map.get(assigns, :defer_path, Deferred.path()),
      defer_token: Map.get(assigns, :defer_token),
      defer_endpoint:
        Map.get(assigns, :defer_endpoint) ||
          Application.get_env(:live_islands, :deferred_endpoint),
      defer_timeout: Map.get(assigns, :defer_timeout, 10_000),
      defer_cache_control:
        Map.get(assigns, :defer_cache_control) || Map.get(assigns, :cache_control),
      render_ssr?:
        render_ssr?(assigns, config, init?, dead?, server_only?, component_name, deferred?)
    }
  end

  defp streams_diff?(assigns) do
    Enum.any?(assigns, fn {_key, value} -> match?(%LiveStream{}, value) end)
  end

  defp render_ssr?(assigns, config, init?, dead?, server_only?, component_name, deferred?) do
    (server_only? or (init? and dead?)) and
      not deferred? and
      Map.get(assigns, config.ssr_key, ssr_default()) and not is_nil(component_name)
  end

  defp changed_assigns(assigns, true) do
    Enum.filter(assigns, fn {key, _value} -> key_changed(assigns, key) end)
  end

  defp changed_assigns(assigns, false), do: assigns

  defp island_data(base_assigns, assigns, config, context) do
    props = extract(base_assigns, :props, config)
    streams = extract(base_assigns, :streams, config)
    slots = extract(base_assigns, :slots, config)
    handlers = extract(base_assigns, :handlers, config)

    %{
      props: props,
      slots: slots,
      handlers: handlers,
      props_diff: props_diff(props, assigns, context.use_diff),
      streams_diff: streams_diff(streams, context)
    }
  end

  defp props_diff(props, assigns, true), do: calculate_props_diff(props, assigns)
  defp props_diff(_props, _assigns, false), do: []

  defp streams_diff(streams, %{use_streams_diff: true} = context) do
    calculate_streams_diff(streams, context.init? or context.dead?)
  end

  defp streams_diff(_streams, _context), do: []

  defp put_island_assigns(assigns, config, context, data) do
    assigns
    |> Map.put_new(:class, nil)
    |> Map.put_new(:fallback, [])
    |> Map.put(:__framework, config.framework)
    |> Map.put(:__hook, if(context.server_only?, do: nil, else: config.hook))
    |> Map.put(:__component_name, context.component_name)
    |> validate_component!(config)
    |> then(fn assigns ->
      Map.put_new_lazy(assigns, :id, fn -> id(context.component_name, config.counter_key) end)
    end)
    |> Map.put(:props, data.props)
    |> Map.put(:props_diff, Patch.serialize(data.props_diff))
    |> Map.put(:streams_diff, Patch.serialize(data.streams_diff))
    |> Map.put(:handlers, data.handlers)
    |> Map.put(:slots, Slots.rendered_slot_map(data.slots, config.framework))
    |> Map.put(:use_diff, context.use_diff)
    |> Map.put(:client, context.client)
    |> Map.put(:client_media, context.client_media)
    |> Map.put(:prefetch, context.prefetch)
    |> Map.put(:prefetch_media, context.prefetch_media)
    |> Map.put(:inject_target, context.inject_target)
    |> Map.put(:inject_slot, context.inject_slot)
    |> Map.put(:server_only?, context.server_only?)
    |> Map.put(:deferred?, context.deferred?)
  end

  defp put_ssr_render(assigns, true), do: Map.put(assigns, :ssr_render, ssr_render(assigns))
  defp put_ssr_render(assigns, false), do: Map.put(assigns, :ssr_render, nil)

  defp put_deferred_render(assigns, %{deferred?: false}) do
    assigns
    |> Map.put(:defer_src, nil)
    |> Map.put(:defer_timeout, nil)
    |> Map.put(:defer_state, nil)
  end

  defp put_deferred_render(assigns, %{deferred?: true} = context) do
    if is_nil(context.defer_token) and is_nil(context.defer_endpoint) do
      raise ArgumentError,
            "deferred server islands require config :live_islands, :deferred_endpoint or a :defer_endpoint assign"
    end

    payload = %{
      framework: assigns.__framework,
      name: assigns.__component_name,
      props: Encoder.encode(assigns.props),
      slots: assigns.slots,
      cache_control: context.defer_cache_control
    }

    src =
      Deferred.signed_path(payload,
        endpoint: context.defer_endpoint,
        path: context.defer_path,
        token: context.defer_token
      )

    assigns
    |> Map.put(:defer_src, src)
    |> Map.put(:defer_timeout, context.defer_timeout)
    |> Map.put(:defer_state, "pending")
  end

  defp put_computed_changed(assigns, context, data) do
    computed_changed = %{
      props: context.init? or context.dead? or not context.use_diff,
      slots: data.slots != %{},
      handlers: data.handlers != %{},
      ssr_render: is_map(assigns.ssr_render) or context.deferred?,
      props_diff: not context.init? and not context.dead? and context.use_diff,
      streams_diff: context.use_streams_diff
    }

    update_in(assigns.__changed__, fn
      nil -> nil
      changed -> for {key, true} <- computed_changed, into: changed, do: {key, true}
    end)
  end

  defp put_render_flags(assigns, config, context) do
    assigns
    |> Map.put(:ssr_html, ssr_html(assigns.ssr_render))
    |> Map.put(:ssr?, is_map(assigns.ssr_render))
    |> Map.put(:hidden_style, if(assigns.inject_target, do: "display:none", else: nil))
    |> Map.put(:no_format?, if(context.server_only?, do: nil, else: config.framework == :vue))
    |> Map.put(
      :phx_update,
      if(context.server_only? and not context.deferred?, do: nil, else: "ignore")
    )
  end

  defp ssr_html(%{} = render), do: render[:html]
  defp ssr_html(_render), do: nil

  defp defer?(assigns) do
    case Map.get(assigns, :defer, false) do
      value when value in [true, :load, "true", "load", "defer"] -> true
      _ -> false
    end
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

  defp client_config(assigns, config) do
    client =
      config.client_keys
      |> Enum.find_value(&Map.get(assigns, &1))
      |> normalize_client()

    media =
      config.client_media_keys
      |> Enum.find_value(&Map.get(assigns, &1))

    case client do
      {:media, query} -> {"media", query}
      mode -> {mode, media}
    end
  end

  defp normalize_client(nil), do: "load"
  defp normalize_client(false), do: "none"
  defp normalize_client(:load), do: "load"
  defp normalize_client(:idle), do: "idle"
  defp normalize_client(:visible), do: "visible"
  defp normalize_client(:interaction), do: "interaction"
  defp normalize_client(:none), do: "none"
  defp normalize_client({:media, query}), do: {:media, query}
  defp normalize_client({"media", query}), do: {:media, query}
  defp normalize_client({:custom, value}) when is_binary(value), do: value
  defp normalize_client("load"), do: "load"
  defp normalize_client("idle"), do: "idle"
  defp normalize_client("visible"), do: "visible"
  defp normalize_client("interaction"), do: "interaction"
  defp normalize_client("none"), do: "none"
  defp normalize_client("media"), do: "media"
  defp normalize_client(value) when is_binary(value), do: value

  defp normalize_client(value) do
    raise ArgumentError,
          "LiveIslands client must be :load, :idle, :visible, :interaction, :none, {:media, query}, {:custom, name}, or a matching string; got #{inspect(value)}"
  end

  defp prefetch_config(assigns, config) do
    prefetch =
      config.prefetch_keys
      |> Enum.find_value(&Map.get(assigns, &1))
      |> normalize_prefetch()

    media =
      config.prefetch_media_keys
      |> Enum.find_value(&Map.get(assigns, &1))

    case prefetch do
      {:media, query} -> {"media", query}
      mode -> {mode, media}
    end
  end

  defp normalize_prefetch(nil), do: nil
  defp normalize_prefetch(true), do: "visible"
  defp normalize_prefetch(false), do: "none"
  defp normalize_prefetch(:load), do: "load"
  defp normalize_prefetch(:eager), do: "load"
  defp normalize_prefetch(:idle), do: "idle"
  defp normalize_prefetch(:visible), do: "visible"
  defp normalize_prefetch(:viewport), do: "visible"
  defp normalize_prefetch(:hover), do: "hover"
  defp normalize_prefetch(:tap), do: "tap"
  defp normalize_prefetch(:interaction), do: "interaction"
  defp normalize_prefetch(:none), do: "none"
  defp normalize_prefetch({:media, query}), do: {:media, query}
  defp normalize_prefetch({"media", query}), do: {:media, query}
  defp normalize_prefetch({:custom, value}) when is_binary(value), do: value
  defp normalize_prefetch("load"), do: "load"
  defp normalize_prefetch("eager"), do: "load"
  defp normalize_prefetch("idle"), do: "idle"
  defp normalize_prefetch("visible"), do: "visible"
  defp normalize_prefetch("viewport"), do: "visible"
  defp normalize_prefetch("hover"), do: "hover"
  defp normalize_prefetch("tap"), do: "tap"
  defp normalize_prefetch("interaction"), do: "interaction"
  defp normalize_prefetch("none"), do: "none"
  defp normalize_prefetch("media"), do: "media"
  defp normalize_prefetch(value) when is_binary(value), do: value

  defp normalize_prefetch(value) do
    raise ArgumentError,
          "LiveIslands prefetch must be :load, :idle, :visible, :hover, :tap, :interaction, :none, {:media, query}, {:custom, name}, or a matching string; got #{inspect(value)}"
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
