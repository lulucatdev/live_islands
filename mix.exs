defmodule LiveIslands.MixProject do
  use Mix.Project

  @source_url "https://github.com/lulucatdev/live_islands"
  @version "0.11.2"

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
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
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
        ~w(assets/copy assets/js benchmarks/README.md guides lib skills)s ++
          ~w(CHANGELOG.md LICENSE.md Makefile NOTICE.md logo.svg mix.exs package.json README.md .formatter.exs)s
    ]
  end

  defp docs do
    [
      name: "LiveIslands",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @source_url,
      canonical: "https://hexdocs.pm/live_islands",
      logo: "logo.svg",
      favicon: "logo.svg",
      main: "readme",
      extra_section: "Guides",
      extras: [
        "README.md": [filename: "readme", title: "Overview"],
        "guides/installation.md": [filename: "installation", title: "Installation"],
        "guides/lazy-islands.md": [filename: "lazy-islands", title: "Lazy Islands"],
        "guides/ssr.md": [filename: "ssr", title: "Server-Side Rendering"],
        "guides/deployment.md": [filename: "deployment", title: "Deployment"],
        "guides/development.md": [filename: "development", title: "Development"],
        "benchmarks/README.md": [filename: "benchmarks", title: "Benchmarks"],
        "guides/documentation.md": [filename: "documentation", title: "Documentation"],
        "skills/live-islands-install/SKILL.md": [
          filename: "agent-install-skill",
          title: "Agent Install Skill"
        ],
        "skills/live-islands-install/references/integration-checklist.md": [
          filename: "install-integration-checklist",
          title: "Install Integration Checklist"
        ],
        "skills/live-islands-install/references/verification.md": [
          filename: "install-verification",
          title: "Install Verification"
        ],
        "guides/performance-roadmap.md": [
          filename: "performance-roadmap",
          title: "Performance Roadmap"
        ],
        "CHANGELOG.md": [filename: "changelog", title: "Changelog"],
        "NOTICE.md": [filename: "notice", title: "Notice"],
        "LICENSE.md": [filename: "license", title: "License"]
      ],
      groups_for_extras: [
        Start: ["README.md", "guides/installation.md"],
        Runtime: ["guides/lazy-islands.md", "guides/ssr.md", "guides/deployment.md"],
        Operations: ["guides/development.md", "benchmarks/README.md", "guides/documentation.md"],
        "Agent Installation": [
          "skills/live-islands-install/SKILL.md",
          "skills/live-islands-install/references/integration-checklist.md",
          "skills/live-islands-install/references/verification.md"
        ],
        Reference: ["guides/performance-roadmap.md", "CHANGELOG.md", "NOTICE.md", "LICENSE.md"]
      ],
      groups_for_modules: [
        Components: [LiveIslands, LiveIslands.React, LiveIslands.Vue],
        Runtime: [LiveIslands.Reload, LiveIslands.Deferred],
        "Server-Side Rendering": [
          LiveIslands.SSR,
          LiveIslands.SSR.NodeJS,
          LiveIslands.SSR.ViteJS
        ],
        Encoding: [LiveIslands.Encoder, LiveIslands.Patch],
        Testing: [LiveIslands.Test],
        "Mix Tasks": [
          Mix.Tasks.LiveIslands.Install,
          Mix.Tasks.LiveIslands.VerifyInstall
        ]
      ],
      nest_modules_by_prefix: [LiveIslands]
    ]
  end
end
