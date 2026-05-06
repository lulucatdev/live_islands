defmodule LiveIslands.Reload do
  @moduledoc """
  Utilities for easier integration with Vite in development
  """

  use Phoenix.Component

  attr(:assets, :list, required: true)

  attr(:manifest_path, :string,
    default: nil,
    doc: "optional path to the Vite build manifest for production asset tags"
  )

  slot(:inner_block, required: true, doc: "what should be rendered when Vite path is not defined")

  @doc """
  Renders Vite dev server assets in development and Vite manifest assets in production.
  """
  def vite_assets(assigns) do
    vite_host = Application.get_env(:live_islands, :vite_host)

    assigns =
      assigns
      |> assign(:vite_host, vite_host)
      |> assign(
        :stylesheets,
        for(path <- assigns.assets, String.ends_with?(path, ".css"), do: path)
      )
      |> assign(
        :javascripts,
        for(
          path <- assigns.assets,
          String.ends_with?(path, ".js") || String.ends_with?(path, ".ts"),
          do: path
        )
      )
      |> assign(
        :production_assets,
        if(vite_host,
          do: empty_production_assets(),
          else: production_assets(assigns.assets, assigns.manifest_path)
        )
      )

    # maybe make it configurable in other way than by presence of vite_host config?
    # https://vitejs.dev/guide/backend-integration.html
    ~H"""
    <%= if @vite_host do %>
      <script type="module">
        import RefreshRuntime from '<%= LiveIslands.SSR.ViteJS.vite_path("@react-refresh") %>'
        RefreshRuntime.injectIntoGlobalHook(window)
        window.$RefreshReg$ = () => {}
        window.$RefreshSig$ = () => (type) => type
        window.__vite_plugin_react_preamble_installed__ = true
      </script>
      <script type="module" src={LiveIslands.SSR.ViteJS.vite_path("@vite/client")}>
      </script>
      <link :for={path <- @stylesheets} rel="stylesheet" href={LiveIslands.SSR.ViteJS.vite_path(path)} />
      <script :for={path <- @javascripts} type="module" src={LiveIslands.SSR.ViteJS.vite_path(path)}>
      </script>
    <% else %>
      <%= if @production_assets.found? do %>
        <link
          :for={path <- @production_assets.stylesheets}
          phx-track-static
          rel="stylesheet"
          href={path}
        />
        <script
          :for={path <- @production_assets.javascripts}
          type="module"
          phx-track-static
          src={path}
        >
        </script>
      <% else %>
        <%= render_slot(@inner_block) %>
      <% end %>
    <% end %>
    """
  end

  defp empty_production_assets do
    %{found?: false, stylesheets: [], javascripts: []}
  end

  defp production_assets(assets, manifest_path) do
    with {:ok, manifest} <- read_manifest(manifest_path) do
      entries =
        assets
        |> Enum.map(&normalize_asset/1)
        |> Enum.flat_map(&manifest_entries(manifest, &1))

      stylesheets =
        entries
        |> Enum.flat_map(&Map.get(&1, "css", []))
        |> Enum.map(&asset_path/1)
        |> Enum.uniq()

      javascripts =
        entries
        |> Enum.map(&Map.get(&1, "file"))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&(String.ends_with?(&1, ".js") or String.ends_with?(&1, ".mjs")))
        |> Enum.map(&asset_path/1)
        |> Enum.uniq()

      %{found?: entries != [], stylesheets: stylesheets, javascripts: javascripts}
    else
      _ -> %{found?: false, stylesheets: [], javascripts: []}
    end
  end

  defp read_manifest(nil) do
    manifest_path =
      cond do
        path = Application.get_env(:live_islands, :vite_manifest_path) ->
          expand_manifest_path(path)

        otp_app = Application.get_env(:live_islands, :otp_app) ->
          Application.app_dir(otp_app, "priv/static/assets/.vite/manifest.json")

        true ->
          Path.expand("priv/static/assets/.vite/manifest.json")
      end

    read_manifest(manifest_path)
  end

  defp read_manifest(manifest_path) do
    with {:ok, content} <- File.read(manifest_path),
         {:ok, manifest} <- Jason.decode(content) do
      {:ok, manifest}
    end
  end

  defp expand_manifest_path(path) do
    if Path.type(path) == :absolute do
      path
    else
      Path.expand(path)
    end
  end

  defp normalize_asset(path) do
    path
    |> to_string()
    |> String.trim_leading("/")
  end

  defp manifest_entries(manifest, path) do
    case Map.get(manifest, path) || find_manifest_entry_by_src(manifest, path) do
      nil -> []
      entry -> [entry]
    end
  end

  defp find_manifest_entry_by_src(manifest, path) do
    Enum.find_value(manifest, fn {_key, value} ->
      if Map.get(value, "src") == path, do: value
    end)
  end

  defp asset_path(file), do: "/assets/#{file}"
end
