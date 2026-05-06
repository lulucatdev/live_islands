defmodule LiveIslandsInstallerTest do
  use ExUnit.Case

  alias LiveIslands.Installer

  describe "patch_app_js/1" do
    test "adds imports and hooks to a default LiveSocket configuration" do
      content = """
      import { Socket } from "phoenix";
      import { LiveSocket } from "phoenix_live_view";
      import topbar from "topbar";

      let liveSocket = new LiveSocket("/live", Socket, {
        params: { _csrf_token: csrfToken }
      });
      """

      patched = Installer.patch_app_js(content)

      assert patched =~ ~s(import components from "../react-components";)
      assert patched =~ ~s(import { getHooks } from "live_islands/react";)
      assert patched =~ "hooks: getHooks(components),"
    end

    test "merges with an existing hooks option" do
      content = """
      import topbar from "topbar";

      let liveSocket = new LiveSocket("/live", Socket, {
        hooks: Hooks,
        params: { _csrf_token: csrfToken }
      });
      """

      patched = Installer.patch_app_js(content)

      assert patched =~ "hooks: {...Hooks, ...getHooks(components)},"
    end

    test "does not duplicate existing imports or hooks" do
      content = """
      import topbar from "topbar";
      import components from "../react-components";
      import { getHooks } from "live_islands/react";

      let liveSocket = new LiveSocket("/live", Socket, {
        hooks: getHooks(components),
        params: { _csrf_token: csrfToken }
      });
      """

      assert Installer.patch_app_js(content) == content
    end
  end

  describe "configuration patches" do
    test "base config enables SSR and props diffing once" do
      content = "import Config\n"
      patched = Installer.patch_base_config(content)

      assert patched =~ "enable_props_diff: true"
      assert Installer.patch_base_config(patched) == patched
    end

    test "environment config patches are idempotent" do
      dev = Installer.patch_dev_config("import Config\n")
      prod = Installer.patch_prod_config("import Config\n")

      assert dev =~ "LiveIslands.SSR.ViteJS"
      assert prod =~ "LiveIslands.SSR.NodeJS"
      assert Installer.patch_dev_config(dev) == dev
      assert Installer.patch_prod_config(prod) == prod
    end
  end
end
