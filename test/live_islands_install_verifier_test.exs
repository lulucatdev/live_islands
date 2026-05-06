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

  defp project_fixture do
    project_root = tmp_dir!("live_islands_verified_project")

    write!(project_root, "mix.exs", """
    defmodule Demo.MixProject do
      defp deps, do: [{:live_islands, "~> 0.1.0"}]
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
        "@vitejs/plugin-react": "^4.3.0",
        "@vitejs/plugin-vue": "^6.0.0"
      }
    }
    """)

    write!(project_root, "assets/vite.config.js", """
    import react from "@vitejs/plugin-react";
    import vue from "@vitejs/plugin-vue";
    import liveIslandsPlugin from "live_islands/vite-plugin";
    export default { plugins: [react(), vue(), liveIslandsPlugin()] };
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

    write!(project_root, "assets/react-components/index.js", "export default {};\n")
    write!(project_root, "assets/vue-components/index.js", "export default {};\n")

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
