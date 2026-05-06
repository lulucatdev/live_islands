defmodule LiveIslandsInstallerTest do
  use ExUnit.Case, async: true

  alias LiveIslands.Installer

  test "patch_mix_exs swaps Phoenix asset aliases from esbuild/tailwind to npm and Vite" do
    mix_exs = """
    defmodule Demo.MixProject do
      defp deps do
        [
          {:phoenix, "~> 1.8.0"},
          {:phoenix_live_view, "~> 1.1.0"},
          {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
          {:tailwind, "~> 0.4", runtime: Mix.env() == :dev}
        ]
      end

      defp aliases do
        [
          setup: ["deps.get", "assets.setup", "assets.build"],
          "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
          "assets.build": ["compile", "tailwind default", "esbuild default"],
          "assets.deploy": [
            "tailwind default --minify",
            "esbuild default --minify",
            "phx.digest"
          ]
        ]
      end
    end
    """

    updated = Installer.patch_mix_exs(mix_exs)

    refute updated =~ "{:esbuild,"
    refute updated =~ "{:tailwind,"
    refute updated =~ "tailwind default"
    refute updated =~ "esbuild default"
    assert updated =~ ~s({:nodejs, "~> 3.1"},)
    assert updated =~ ~s("assets.setup": ["cmd --cd assets npm install"])
    assert updated =~ ~s("assets.build": ["compile", "cmd --cd assets npm run build")
    assert updated =~ ~s("assets.deploy": ["cmd --cd assets npm run build")
    assert Installer.patch_mix_exs(updated) == updated
  end

  test "patch_package_json points npm at the actual LiveIslands dependency path" do
    package_json = """
    {
      "private": true,
      "dependencies": {
        "live_islands": "file:../deps/live_islands",
        "phoenix": "file:../deps/phoenix"
      }
    }
    """

    updated =
      package_json
      |> Installer.patch_package_json(
        "/Users/lucas/Developer/live_islands_smoke",
        "/Users/lucas/Developer/live_react_alignment/live_react"
      )
      |> Jason.decode!()

    assert updated["dependencies"]["live_islands"] == "file:../../live_react_alignment/live_react"
    assert updated["dependencies"]["phoenix"] == "file:../deps/phoenix"
  end

  test "patch_vite_config resolves Phoenix colocated hooks from the Mix build path" do
    vite_config = """
    import path from "path";
    import { defineConfig } from "vite";

    export default defineConfig(({ command }) => {
      const isDev = command !== "build";

      return {
        resolve: {
          alias: {
            "@": path.resolve(__dirname, "."),
          },
        },
      };
    });
    """

    updated = Installer.patch_vite_config(vite_config)

    assert updated =~ ~s(const mixEnv = process.env.MIX_ENV || "dev";)
    assert updated =~ ~S|"phoenix-colocated": path.resolve(|
    assert updated =~ "../_build/${mixEnv}/phoenix-colocated"
    assert Installer.patch_vite_config(updated) == updated
  end

  test "patch_app_js preserves colocated hooks and adds React and Vue island hooks" do
    app_js = """
    import "phoenix_html";
    import { Socket } from "phoenix";
    import { LiveSocket } from "phoenix_live_view";
    import topbar from "../vendor/topbar";
    import { hooks as colocatedHooks } from "phoenix-colocated/demo";

    // If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
    // To load it, simply add a second `<link>` to your `root.html.heex` file.

    let liveSocket = new LiveSocket("/live", Socket, {
      longPollFallbackMs: 2500,
      hooks: {...colocatedHooks},
      params: {_csrf_token: csrfToken}
    });
    """

    updated = Installer.patch_app_js(app_js)

    assert updated =~ ~s(import topbar from "topbar";)
    assert updated =~ ~s(import { getIslandHooks } from "live_islands";)
    assert updated =~ ~s(import reactComponents from "../react-components";)
    assert updated =~ ~s(import vueComponents from "../vue-components";)
    refute updated =~ "esbuild will generate"

    assert updated =~
             "hooks: {...colocatedHooks, ...getIslandHooks({react: reactComponents, vue: vueComponents})},"

    assert Installer.patch_app_js(updated) == updated
  end

  test "patch_app_css keeps Tailwind CSS sources and removes daisyUI" do
    app_css = """
    @import "tailwindcss" source(none);
    @source "../css";
    @source "../js";
    @source "../../lib/demo_web";

    /* daisyUI Tailwind Plugin. You can update this file by fetching the latest version with:
       curl -sLO https://github.com/saadeghi/daisyui/releases/latest/download/daisyui.js
    */
    @plugin "../vendor/daisyui" {
      themes: false;
    }

    /* daisyUI theme plugin. You can update this file by fetching the latest version with:
      curl -sLO https://github.com/saadeghi/daisyui/releases/latest/download/daisyui-theme.js
    */
    @plugin "../vendor/daisyui-theme" {
      name: "dark";
      default: false;
      prefersdark: true;
    }

    /* Add variants based on LiveView classes. */
    @custom-variant phx-click-loading (.phx-click-loading&, .phx-click-loading &);
    """

    updated = Installer.patch_app_css(app_css)

    refute updated =~ "daisyUI"
    refute updated =~ "../vendor/daisyui"
    assert updated =~ ~S|@import "tailwindcss" source(none);|
    assert updated =~ ~s(@source "../react-components";)
    assert updated =~ ~s(@source "../vue-components";)
    assert updated =~ ~s(@source "../../lib";)
  end

  test "patch_tsconfig replaces Phoenix's esbuild-oriented TypeScript defaults" do
    tsconfig = """
    // This file is needed on most editors to enable the intelligent autocompletion
    // of LiveView's JavaScript API methods.
    //
    // Note: This file assumes a basic esbuild setup without node_modules.
    // We include a generic paths alias to deps to mimic how esbuild resolves
    // the Phoenix and LiveView JavaScript assets.
    {
      "compilerOptions": {
        "baseUrl": ".",
        "paths": {
          "*": ["../deps/*"]
        },
        "allowJs": true,
        "noEmit": true
      },
      "include": ["js/**/*"]
    }
    """

    updated = Installer.patch_tsconfig(tsconfig)

    refute updated =~ "esbuild"
    assert updated =~ ~s("types": ["vite/client"])
    assert updated =~ ~s("include": ["js/*", "react-components/**/*", "vue-components/**/*"])
  end

  test "patch_base_config removes Phoenix esbuild and tailwind config without confusing app names" do
    config = """
    import Config

    config :live_islands_smoke,
      generators: [timestamp_type: :utc_datetime]

    # Configure esbuild (the version is required)
    config :esbuild,
      version: "0.25.4",
      demo: [
        args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets),
        cd: Path.expand("../assets", __DIR__),
        env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
      ]

    # Configure tailwind (the version is required)
    config :tailwind,
      version: "4.1.12",
      demo: [
        args: ~w(
          --input=assets/css/app.css
          --output=priv/static/assets/app.css
        ),
        cd: Path.expand("..", __DIR__)
      ]

    # Configure Elixir's Logger
    config :logger, :default_formatter,
      format: "$time $metadata[$level] $message\\n"

    # Import environment specific config. This must remain at the bottom
    # of this file so it overrides the configuration defined above.
    import_config "\#{config_env()}.exs"
    """

    updated = Installer.patch_base_config(config)

    refute updated =~ "config :esbuild"
    refute updated =~ "config :tailwind"
    assert updated =~ "config :live_islands_smoke"
    assert updated =~ "config :live_islands,\n  ssr: true,\n  enable_props_diff: true"

    [before_import, _after_import] =
      String.split(updated, ~S|import_config "#{config_env()}.exs"|, parts: 2)

    assert before_import =~ "config :live_islands,"
  end

  test "patch_dev_config replaces Phoenix 1.8 watchers with the Vite watcher" do
    dev_config = """
    import Config

    config :demo, DemoWeb.Endpoint,
      http: [ip: {127, 0, 0, 1}, port: 4000],
      watchers: [
        esbuild: {Esbuild, :install_and_run, [:demo, ~w(--sourcemap=inline --watch)]},
        tailwind: {Tailwind, :install_and_run, [:demo, ~w(--watch)]}
      ]
    """

    updated = Installer.patch_dev_config(dev_config)

    refute updated =~ "Esbuild"
    refute updated =~ "Tailwind"
    assert updated =~ ~S|npm: ["run", "dev", cd: Path.expand("../assets", __DIR__)]|
    assert updated =~ "ssr_module: LiveIslands.SSR.ViteJS"
  end

  test "patch_web_module adds LiveIslands import even when the app name includes LiveIslands" do
    web_module = """
    defmodule LiveIslandsSmokeWeb do
      defp html_helpers do
        quote do
          use Phoenix.HTML
          import Phoenix.HTML
        end
      end
    end
    """

    assert Installer.patch_web_module(web_module) =~ "import LiveIslands"
  end

  test "patch_root_layout wraps Phoenix asset tags with the Vite dev helper" do
    root_layout = """
    <head>
      <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
      <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
      </script>
    </head>
    """

    updated = Installer.patch_root_layout(root_layout)

    assert updated =~ "LiveIslands.Reload.vite_assets"
    assert updated =~ ~s(assets={["/js/app.js", "/css/app.css"]})
    assert updated =~ ~s(type="module" phx-track-static src={~p"/assets/app.js"})
  end
end
