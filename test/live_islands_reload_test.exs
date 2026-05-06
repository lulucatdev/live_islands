defmodule LiveIslandsReloadTest do
  use ExUnit.Case, async: false

  import Phoenix.Component
  import Phoenix.LiveViewTest

  def assets_component(assigns) do
    ~H"""
    <LiveIslands.Reload.vite_assets assets={["/js/app.js", "/css/app.css"]}>
      <link phx-track-static rel="stylesheet" href="/assets/app.css" />
      <script type="module" phx-track-static src="/assets/app.js">
      </script>
    </LiveIslands.Reload.vite_assets>
    """
  end

  setup do
    previous =
      Map.new([:vite_host, :vite_manifest_path, :otp_app], fn key ->
        {key, Application.get_env(:live_islands, key)}
      end)

    Application.delete_env(:live_islands, :vite_host)
    Application.delete_env(:live_islands, :vite_manifest_path)
    Application.delete_env(:live_islands, :otp_app)

    on_exit(fn ->
      Enum.each(previous, fn
        {key, nil} -> Application.delete_env(:live_islands, key)
        {key, value} -> Application.put_env(:live_islands, key, value)
      end)
    end)

    :ok
  end

  test "renders Vite manifest assets in the production fallback" do
    manifest_path = tmp_manifest_path()

    File.write!(manifest_path, """
    {
      "js/app.js": {
        "file": "app-BnY7NwGx.js",
        "src": "js/app.js",
        "isEntry": true,
        "css": ["app-BECRn7UL.css"]
      }
    }
    """)

    Application.put_env(:live_islands, :vite_manifest_path, manifest_path)

    html = render_component(&assets_component/1)

    assert html =~ ~s(href="/assets/app-BECRn7UL.css")
    assert html =~ ~s(src="/assets/app-BnY7NwGx.js")
    refute html =~ ~s(src="/assets/app.js")
  end

  test "falls back to the slot when the Vite manifest is unavailable" do
    html = render_component(&assets_component/1)

    assert html =~ ~s(href="/assets/app.css")
    assert html =~ ~s(src="/assets/app.js")
  end

  defp tmp_manifest_path do
    dir =
      Path.join(
        System.tmp_dir!(),
        "live_islands_vite_manifest_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    Path.join(dir, "manifest.json")
  end
end
