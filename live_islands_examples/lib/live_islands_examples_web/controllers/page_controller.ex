defmodule LiveIslandsExamplesWeb.PageController do
  use LiveIslandsExamplesWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/simple")
  end

  def simple(conn, _params) do
    render(conn, :simple, demo: :simple)
  end

  def simple_props(conn, _params) do
    render(conn, :simple_props, demo: :simple_props)
  end

  def typescript(conn, _params) do
    render(conn, :typescript, demo: :typescript)
  end

  def lazy(conn, _params) do
    render(conn, :lazy, demo: :lazy)
  end

  def server_only(conn, _params) do
    conn
    |> LiveIslands.put_asset_profile(:server_only)
    |> put_layout(false)
    |> render(:server_only,
      metrics: metrics(),
      samples: samples(),
      sections: sections()
    )
  end

  def profile_react_only(conn, _params) do
    conn
    |> LiveIslands.put_asset_profile(:islands)
    |> put_layout(false)
    |> render(:profile_react_only)
  end

  def profile_vue_only(conn, _params) do
    conn
    |> LiveIslands.put_asset_profile(:islands)
    |> put_layout(false)
    |> render(:profile_vue_only, samples: samples())
  end

  def profile_mixed(conn, _params) do
    conn
    |> LiveIslands.put_asset_profile(:islands)
    |> put_layout(false)
    |> render(:profile_mixed, samples: samples())
  end

  defp metrics do
    %{
      "documents" => 128,
      "formulas" => 96,
      "pdf_pages" => 12,
      "stream_rows" => 480
    }
  end

  defp sections do
    [
      %{title: "React SSR", score: 99, weight: "zero hook"},
      %{title: "Vue SSR", score: 98, weight: "zero hydration"},
      %{title: "Client chunks", score: 100, weight: "not loaded"}
    ]
  end

  defp samples do
    for index <- 1..6 do
      %{
        id: index,
        label: "Proof #{index}",
        value: 80 + rem(index * 7, 17)
      }
    end
  end
end
