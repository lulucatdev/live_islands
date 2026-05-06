defmodule LiveIslands.MixProject do
  use Mix.Project

  @source_url "https://github.com/lulucatdev/live_islands"
  @version "0.1.0"

  def project do
    [
      app: :live_islands,
      version: @version,
      consolidate_protocols: Mix.env() != :test,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Astro-style React and Vue component islands for Phoenix LiveView",
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    conditionals =
      case Application.get_env(:live_islands, :ssr_module) do
        # Needed to use :httpc.request
        LiveIslands.SSR.ViteJS -> [:inets]
        _ -> []
      end

    [
      extra_applications: [:logger] ++ conditionals
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.2"},
      {:nodejs, "~> 3.1", optional: true},
      {:floki, ">= 0.30.0", optional: true},
      {:phoenix, ">= 1.7.0"},
      {:phoenix_html, ">= 3.3.1"},
      {:phoenix_live_view, ">= 0.18.0"},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:jsonpatch, "~> 2.3"},
      {:ecto, "~> 3.0", optional: true},
      {:phoenix_ecto, "~> 4.0", optional: true},
      {:credo, "~> 1.7", only: [:dev, :test]},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:git_ops, "~> 2.8.0", only: [:dev]}
    ]
  end

  defp package do
    [
      maintainers: ["LiveIslands contributors"],
      licenses: ["MIT"],
      links: %{
        Github: @source_url
      },
      files:
        ~w(assets/copy assets/js guides lib skills)s ++
          ~w(CHANGELOG.md LICENSE.md NOTICE.md mix.exs package.json README.md .formatter.exs)s
    ]
  end

  defp docs do
    [
      name: "LiveIslands",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @source_url,
      main: "readme",
      extras: [
        "README.md",
        "guides/installation.md",
        "guides/lazy-islands.md",
        "guides/deployment.md",
        "guides/development.md",
        "guides/ssr.md",
        "CHANGELOG.md"
      ]
    ]
  end
end
