defmodule LiveIslandsDeferredTestEndpoint do
  use Phoenix.Endpoint, otp_app: :live_islands
end

defmodule LiveIslandsDeferredTestSSR do
  @behaviour LiveIslands.SSR

  def render(framework, name, props, _slots) do
    %{
      html:
        ~s(<section data-testid="deferred-result" data-framework="#{framework}" data-name="#{name}">#{props["title"]}</section>)
    }
  end
end

defmodule LiveIslandsDeferredTest do
  use ExUnit.Case

  import LiveIslands
  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias LiveIslands.Deferred
  alias LiveIslands.Test

  setup do
    old_endpoint = Application.get_env(:live_islands, :deferred_endpoint)
    old_ssr = Application.get_env(:live_islands, :ssr_module)
    endpoint_config = Application.get_env(:live_islands, LiveIslandsDeferredTestEndpoint)

    Application.put_env(:live_islands, LiveIslandsDeferredTestEndpoint,
      secret_key_base: String.duplicate("a", 64),
      url: [host: "example.com"]
    )

    Application.put_env(:live_islands, :deferred_endpoint, LiveIslandsDeferredTestEndpoint)
    Application.put_env(:live_islands, :ssr_module, LiveIslandsDeferredTestSSR)
    start_supervised!(LiveIslandsDeferredTestEndpoint)

    on_exit(fn ->
      restore_env(:deferred_endpoint, old_endpoint)
      restore_env(:ssr_module, old_ssr)
      restore_env(LiveIslandsDeferredTestEndpoint, endpoint_config)
    end)

    :ok
  end

  def deferred_component(assigns) do
    ~H"""
    <.react_server
      id="deferred-react"
      name="DeferredReact"
      title="Deferred title"
      defer={true}
      defer_token="test-token"
      defer_path="/custom/deferred"
      defer_timeout={1234}
    >
      <:fallback>
        <p data-testid="deferred-fallback">Fallback shell</p>
      </:fallback>
    </.react_server>
    """
  end

  test "renders deferred server islands as hookless fallback shells" do
    html = render_component(&deferred_component/1)
    island = Test.get_react(html, id: "deferred-react")

    assert island.server_only
    assert island.deferred
    assert island.ssr == false
    assert island.client == "none"
    assert island.prefetch == "none"
    assert island.hook == nil
    assert island.phx_update == "ignore"
    assert island.defer_state == "pending"
    assert island.defer_src == "/custom/deferred?token=test-token"
    assert html =~ ~s(data-testid="deferred-fallback")
    assert html =~ "Fallback shell"
    refute html =~ ~s(data-testid="deferred-result")
  end

  test "serves signed deferred HTML through the plug" do
    payload = %{
      framework: :react,
      name: "DeferredReact",
      props: %{"title" => "Signed title"},
      slots: %{},
      cache_control: "public, max-age=60"
    }

    token = Deferred.sign(payload, endpoint: LiveIslandsDeferredTestEndpoint)

    conn =
      :get
      |> Plug.Test.conn("/live-islands/deferred?#{URI.encode_query(token: token)}")
      |> Deferred.call(endpoint: LiveIslandsDeferredTestEndpoint)

    assert conn.status == 200
    assert Plug.Conn.get_resp_header(conn, "cache-control") == ["public, max-age=60"]
    assert conn.resp_body =~ ~s(data-testid="deferred-result")
    assert conn.resp_body =~ "Signed title"
  end

  test "rejects invalid deferred tokens" do
    conn =
      :get
      |> Plug.Test.conn("/live-islands/deferred?token=invalid")
      |> Deferred.call(endpoint: LiveIslandsDeferredTestEndpoint)

    assert conn.status == 403
  end

  defp restore_env(key, nil), do: Application.delete_env(:live_islands, key)
  defp restore_env(key, value), do: Application.put_env(:live_islands, key, value)
end
