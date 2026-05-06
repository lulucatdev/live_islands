defmodule LiveIslandsInstallVerifierTest do
  use ExUnit.Case, async: true

  alias LiveIslands.InstallVerifier

  test "verify returns ok when required integration points are present" do
    project_root = project_fixture()

    assert {:ok, checks} = InstallVerifier.verify(project_root)
    assert Enum.all?(checks, & &1.ok?)
  end

  test "verify reports missing integration points" do
    project_root = project_fixture()
    File.rm!(Path.join([project_root, "assets", "js", "app.js"]))

    assert {:error, checks} = InstallVerifier.verify(project_root)
    assert Enum.any?(checks, &(&1.name == "LiveSocket hooks" and not &1.ok?))
  end

  test "verify with artifacts checks the built Vite, SSR, and lazy chunk outputs" do
    project_root = project_fixture()

    write!(project_root, "priv/static/assets/app.js", "import('./simple.js')")
    write!(project_root, "priv/static/assets/app.css", ".text-red-700{}")
    write!(project_root, "priv/static/assets/simple.js", "export default {}")

    write!(
      project_root,
      "priv/static/assets/.vite/manifest.json",
      ~s({"js/app.js":{"file":"app.js","isEntry":true},"react-components/simple.jsx":{"file":"simple.js","isDynamicEntry":true}})
    )

    write!(project_root, "priv/island-components/server.js", "export function render() {}")
    write!(project_root, "priv/island-components/package.json", ~s({"type":"module"}))

    assert {:ok, checks} = InstallVerifier.verify(project_root, artifacts: true)
    assert Enum.any?(checks, &(&1.name == "Vite manifest" and &1.ok?))
    assert Enum.any?(checks, &(&1.name == "lazy chunk artifacts" and &1.ok?))
    assert Enum.any?(checks, &(&1.name == "SSR build artifacts" and &1.ok?))
  end

  test "verify_full runs build commands before checking artifacts" do
    project_root = project_fixture()

    write!(project_root, "priv/static/assets/app.js", "import('./simple.js')")
    write!(project_root, "priv/static/assets/app.css", ".text-red-700{}")
    write!(project_root, "priv/static/assets/simple.js", "export default {}")

    write!(
      project_root,
      "priv/static/assets/.vite/manifest.json",
      ~s({"js/app.js":{"file":"app.js","isEntry":true},"react-components/simple.jsx":{"file":"simple.js","isDynamicEntry":true}})
    )

    write!(project_root, "priv/island-components/server.js", "export function render() {}")
    write!(project_root, "priv/island-components/package.json", ~s({"type":"module"}))

    runner = fn _command, _args, _opts -> {"ok", 0} end

    assert {:ok, checks} = InstallVerifier.verify_full(project_root, runner: runner)
    assert Enum.any?(checks, &(&1.name == "Vite client build" and &1.ok?))
    assert Enum.any?(checks, &(&1.name == "SSR bundle build" and &1.ok?))
  end

  defp project_fixture do
    project_root = tmp_dir!("live_islands_verified_project")

    write!(project_root, "mix.exs", """
    defmodule Demo.MixProject do
      defp deps, do: [{:live_islands, "~> 0.3.0"}]
    end
    """)

    write!(project_root, "assets/package.json", """
    {
      "dependencies": {
        "live_islands": "file:../deps/live_islands",
        "react": "^19.1.0",
        "react-dom": "^19.1.0",
        "vue": "^3.5.0"
      },
      "devDependencies": {
        "vite": "^6.3.0",
        "tailwindcss": "^4.1.0",
        "@tailwindcss/vite": "^4.1.0",
        "@vitejs/plugin-react": "^4.3.0",
        "@vitejs/plugin-vue": "^6.0.0"
      }
    }
    """)

    write!(project_root, "assets/vite.config.js", """
    import react from "@vitejs/plugin-react";
    import vue from "@vitejs/plugin-vue";
    import tailwindcss from "@tailwindcss/vite";
    import liveIslandsPlugin from "live_islands/vite-plugin";
    export default { plugins: [react(), vue(), liveIslandsPlugin(), tailwindcss()], build: { manifest: true } };
    """)

    write!(project_root, "assets/css/app.css", """
    @import "tailwindcss" source(none);
    @source "../react-components";
    @source "../vue-components";
    """)

    write!(project_root, "assets/js/app.js", """
    import { getIslandHooks } from "live_islands";
    import reactComponents from "../react-components";
    import vueComponents from "../vue-components";
    const hooks = getIslandHooks({ react: reactComponents, vue: vueComponents });
    """)

    write!(project_root, "assets/js/server.js", """
    import { getRender as getReactRender } from "live_islands/react/server";
    import { getRender as getVueRender } from "live_islands/vue/server";
    export function render(framework, name, props, slots) {}
    """)

    write!(project_root, "assets/react-components/index.js", """
    import { createReactIsland } from "live_islands/react";
    const components = { Simple: () => import("./simple") };
    export default createReactIsland({ resolve: (name) => components[name]?.() });
    """)

    write!(project_root, "assets/vue-components/index.js", """
    export default import.meta.glob("./**/*.vue");
    """)

    write!(project_root, "lib/demo_web.ex", """
    defmodule DemoWeb do
      defp html_helpers do
        quote do
          import LiveIslands
        end
      end
    end
    """)

    write!(project_root, "lib/demo_web/components/layouts/root.html.heex", """
    <LiveIslands.Reload.vite_assets assets={["/js/app.js", "/css/app.css"]}>
      <script type="module" phx-track-static src={~p"/assets/app.js"}>
      </script>
    </LiveIslands.Reload.vite_assets>
    """)

    write!(project_root, "config/config.exs", """
    import Config
    config :live_islands, ssr: true
    """)

    project_root
  end

  defp write!(project_root, relative_path, content) do
    path = Path.join(project_root, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end

  defp tmp_dir!(name) do
    path = Path.join(System.tmp_dir!(), "#{name}_#{System.unique_integer([:positive])}")
    File.rm_rf!(path)
    File.mkdir_p!(path)
    path
  end
end
