defmodule LiveIslands.Installer do
  @moduledoc false

  @hooks_expression "getIslandHooks({react: reactComponents, vue: vueComponents})"

  @doc false
  def dependency_path do
    Mix.Project.deps_paths(depth: 1)
    |> Map.get(:live_islands, File.cwd!())
  end

  @doc false
  def install(project_root \\ File.cwd!(), dependency_root \\ dependency_path()) do
    copy_templates(project_root, dependency_root)
    patch_project(project_root, dependency_root)
  end

  @doc false
  def copy_templates(project_root, dependency_root) do
    source_root = Path.join([dependency_root, "assets", "copy"])

    source_root
    |> Path.join("**/{*.*}")
    |> Path.wildcard(match_dot: true)
    |> Enum.each(fn full_path ->
      relative_path = Path.relative_to(full_path, source_root)
      new_path = Path.join([project_root, "assets", relative_path])

      if File.exists?(new_path) do
        Mix.shell().info("Keeping existing #{Path.relative_to_cwd(new_path)}")
      else
        Mix.Generator.copy_file(full_path, new_path)
      end
    end)
  end

  @doc false
  def patch_project(project_root, dependency_root \\ dependency_path()) do
    patch_file(Path.join([project_root, "mix.exs"]), &patch_mix_exs/1)

    patch_file(Path.join([project_root, "assets", "package.json"]), fn content ->
      patch_package_json(content, project_root, dependency_root)
    end)

    patch_file(Path.join([project_root, "assets", "vite.config.js"]), &patch_vite_config/1)
    patch_file(Path.join([project_root, "assets", "js", "app.js"]), &patch_app_js/1)
    patch_file(Path.join([project_root, "assets", "css", "app.css"]), &patch_app_css/1)
    patch_file(Path.join([project_root, "assets", "tsconfig.json"]), &patch_tsconfig/1)
    remove_default_daisyui_vendor(project_root)
    patch_file(Path.join([project_root, "config", "config.exs"]), &patch_base_config/1)
    patch_file(Path.join([project_root, "config", "dev.exs"]), &patch_dev_config/1)
    patch_file(Path.join([project_root, "config", "prod.exs"]), &patch_prod_config/1)

    project_root
    |> Path.join("lib/*_web.ex")
    |> Path.wildcard()
    |> Enum.each(&patch_file(&1, fn content -> patch_web_module(content) end))

    project_root
    |> Path.join("lib/*_web/components/layouts/root.html.heex")
    |> Path.wildcard()
    |> Enum.each(&patch_file(&1, fn content -> patch_root_layout(content) end))
  end

  @doc false
  def patch_mix_exs(content) do
    content
    |> remove_dep(:esbuild)
    |> remove_dep(:tailwind)
    |> ensure_nodejs_dep()
    |> replace_assets_alias("assets.setup", ~s(["cmd --cd assets npm install"]))
    |> replace_assets_alias(
      "assets.build",
      ~s(["compile", "cmd --cd assets npm run build", "cmd --cd assets npm run build-server"])
    )
    |> replace_assets_alias(
      "assets.deploy",
      ~s(["cmd --cd assets npm run build", "cmd --cd assets npm run build-server", "phx.digest"])
    )
  end

  @doc false
  def patch_package_json(content, project_root, dependency_root) do
    assets_root = Path.join(project_root, "assets")
    live_islands_path = relative_path(assets_root, dependency_root)

    package = Jason.decode!(content)

    dependencies =
      package
      |> Map.get("dependencies", %{})
      |> Map.put("live_islands", "file:#{live_islands_path}")

    package
    |> Map.put("dependencies", dependencies)
    |> Jason.encode!(pretty: true)
    |> Kernel.<>("\n")
  end

  @doc false
  def patch_vite_config(content) do
    content
    |> ensure_vite_mix_env()
    |> ensure_phoenix_colocated_alias()
  end

  @doc false
  def patch_app_js(content) do
    content
    |> normalize_topbar_import()
    |> remove_phoenix_esbuild_comments()
    |> ensure_import(~s(import { getIslandHooks } from "live_islands";))
    |> ensure_import(~s(import vueComponents from "../vue-components";))
    |> ensure_import(~s(import reactComponents from "../react-components";))
    |> ensure_live_socket_hooks()
  end

  @doc false
  def patch_app_css(content) do
    content
    |> ensure_tailwind_vite_import()
    |> remove_daisyui()
    |> ensure_css_line(~s(@source "../css";))
    |> ensure_css_line(~s(@source "../js";))
    |> ensure_css_line(~s(@source "../react-components";))
    |> ensure_css_line(~s(@source "../vue-components";))
    |> ensure_css_line(~s(@source "../../lib";))
    |> normalize_blank_lines()
  end

  @doc false
  def patch_tsconfig(content) do
    if String.contains?(content, "basic esbuild setup without node_modules") do
      """
      {
        "compilerOptions": {
          "target": "ES2020",
          "lib": ["dom", "dom.iterable", "ES2020"],
          "allowJs": true,
          "skipLibCheck": true,
          "types": ["vite/client"],
          "esModuleInterop": true,
          "allowSyntheticDefaultImports": true,
          "strict": true,
          "forceConsistentCasingInFileNames": true,
          "module": "esnext",
          "moduleResolution": "bundler",
          "isolatedModules": true,
          "resolveJsonModule": true,
          "noEmit": true,
          "jsx": "react",
          "sourceMap": true,
          "declaration": true,
          "noUnusedLocals": true,
          "noUnusedParameters": true,
          "incremental": true,
          "noFallthroughCasesInSwitch": true,

          "paths": {
            "@/*": ["./*"]
          }
        },
        "include": ["js/*", "react-components/**/*", "vue-components/**/*"]
      }
      """
    else
      content
    end
  end

  @doc false
  def patch_base_config(content) do
    content
    |> remove_esbuild_config()
    |> remove_tailwind_config()
    |> append_config_before_env_import(
      "\nconfig :live_islands,",
      """

      config :live_islands,
        ssr: true,
        enable_props_diff: true
      """
    )
  end

  @doc false
  def patch_dev_config(content) do
    content
    |> patch_watchers()
    |> append_config_once(
      "LiveIslands.SSR.ViteJS",
      """

      config :live_islands,
        vite_host: System.get_env("VITE_HOST") || "http://localhost:5173",
        ssr_module: LiveIslands.SSR.ViteJS
      """
    )
  end

  @doc false
  def patch_prod_config(content) do
    append_config_once(
      content,
      "LiveIslands.SSR.NodeJS",
      """

      config :live_islands,
        ssr_module: LiveIslands.SSR.NodeJS
      """
    )
  end

  @doc false
  def patch_web_module(content) do
    cond do
      String.contains?(content, "\n      import LiveIslands\n") ->
        content

      String.contains?(content, "import Phoenix.HTML") ->
        String.replace(content, "      import Phoenix.HTML\n", """
              import Phoenix.HTML
              import LiveIslands
        """)

      true ->
        content
    end
  end

  @doc false
  def patch_root_layout(content) do
    if String.contains?(content, "LiveIslands.Reload.vite_assets") do
      content
    else
      Regex.replace(
        ~r/(\s*)<link phx-track-static rel="stylesheet" href=\{~p"\/assets(?:\/css)?\/app\.css"\} \/>\s*<script(?: defer)? phx-track-static type="text\/javascript" src=\{~p"\/assets(?:\/js)?\/app\.js"\}>\s*<\/script>/s,
        content,
        fn _match, indent ->
          [
            "#{indent}<LiveIslands.Reload.vite_assets assets={[\"/js/app.js\", \"/css/app.css\"]}>",
            "#{indent}  <link phx-track-static rel=\"stylesheet\" href={~p\"/assets/app.css\"} />",
            "#{indent}  <script type=\"module\" phx-track-static src={~p\"/assets/app.js\"}>",
            "#{indent}  </script>",
            "#{indent}</LiveIslands.Reload.vite_assets>"
          ]
          |> Enum.join("\n")
        end
      )
    end
  end

  defp patch_file(path, patcher) do
    if File.exists?(path) do
      original = File.read!(path)
      updated = patcher.(original)

      if updated != original do
        File.write!(path, updated)
        Mix.shell().info("Updated #{Path.relative_to_cwd(path)}")
      end
    end
  end

  defp ensure_import(content, import_line) do
    if String.contains?(content, import_line) do
      content
    else
      case Regex.run(~r/^import topbar from ["'][^"']*topbar["'];?$/m, content) do
        [topbar_import] ->
          String.replace(content, topbar_import, topbar_import <> "\n" <> import_line)

        _ ->
          import_line <> "\n" <> content
      end
    end
  end

  defp ensure_live_socket_hooks(content) do
    cond do
      String.contains?(content, "getIslandHooks({") ->
        content

      Regex.match?(~r/hooks:\s*(\{[^\n]*\}),?/, content) ->
        Regex.replace(~r/hooks:\s*(\{[^\n]*\}),?/, content, fn _match, hooks ->
          hook_entries =
            hooks
            |> String.trim()
            |> String.trim_leading("{")
            |> String.trim_trailing("}")
            |> String.trim()
            |> then(fn hooks ->
              if hooks == "",
                do: "...#{@hooks_expression}",
                else: "#{hooks}, ...#{@hooks_expression}"
            end)

          "hooks: {#{hook_entries}},"
        end)

      true ->
        String.replace(
          content,
          ~r/(new LiveSocket\([^,]+,\s*Socket,\s*\{)/,
          "\\1\n  hooks: #{@hooks_expression},"
        )
    end
  end

  defp append_config_once(content, marker, block) do
    if String.contains?(content, marker),
      do: content,
      else: String.trim_trailing(content) <> block <> "\n"
  end

  defp append_config_before_env_import(content, marker, block) do
    if String.contains?(content, marker) do
      content
    else
      case Regex.run(
             ~r/\n# Import environment specific config\..*?\nimport_config "[^"]*config_env\(\)[^"]*"\n/s,
             content
           ) do
        [import_block] ->
          String.replace(content, import_block, block <> import_block)

        _ ->
          append_config_once(content, marker, block)
      end
    end
  end

  defp remove_dep(content, app) do
    Regex.replace(
      ~r/\n\s*\{:#{app |> Atom.to_string() |> Regex.escape()},[^\n]+\},?/,
      content,
      ""
    )
  end

  defp ensure_nodejs_dep(content) do
    if String.contains?(content, "{:nodejs,") do
      content
    else
      Regex.replace(
        ~r/(\n\s*\{:phoenix_live_view,[^\n]+\},)/,
        content,
        "\\1\n      {:nodejs, \"~> 3.1\"},"
      )
    end
  end

  defp replace_assets_alias(content, alias_name, replacement) do
    alias_pattern = ~r/"#{Regex.escape(alias_name)}":\s*\[.*?\](?=,?\n)/s

    case Regex.run(alias_pattern, content) do
      [existing] ->
        if String.contains?(existing, "cmd --cd assets npm"),
          do: content,
          else: Regex.replace(alias_pattern, content, ~s("#{alias_name}": #{replacement}))

      _ ->
        content
    end
  end

  defp ensure_vite_mix_env(content) do
    if String.contains?(content, "const mixEnv =") do
      content
    else
      String.replace(
        content,
        ~s(  const isDev = command !== "build";\n),
        ~s(  const isDev = command !== "build";\n  const mixEnv = process.env.MIX_ENV || "dev";\n)
      )
    end
  end

  defp ensure_phoenix_colocated_alias(content) do
    if String.contains?(content, ~s("phoenix-colocated")) do
      content
    else
      String.replace(
        content,
        ~S|        "@": path.resolve(__dirname, "."),
|,
        """
                "@": path.resolve(__dirname, "."),
                "phoenix-colocated": path.resolve(
                  __dirname,
                  `../_build/${mixEnv}/phoenix-colocated`,
                ),
        """
      )
    end
  end

  defp ensure_tailwind_vite_import(content) do
    cond do
      String.contains?(content, "@import \"tailwindcss\" source(none);") ->
        content

      String.contains?(content, "@import \"tailwindcss\";") ->
        String.replace(
          content,
          "@import \"tailwindcss\";",
          "@import \"tailwindcss\" source(none);"
        )

      true ->
        "@import \"tailwindcss\" source(none);\n" <> content
    end
  end

  defp ensure_css_line(content, line) do
    if String.contains?(content, line) do
      content
    else
      Regex.replace(
        ~r/(@import "tailwindcss"(?: source\(none\))?;\n)/,
        content,
        "\\1#{line}\n"
      )
    end
  end

  defp remove_daisyui(content) do
    content
    |> then(
      &Regex.replace(
        ~r/\n\/\* daisyUI Tailwind Plugin\..*?@plugin "\.\.\/vendor\/daisyui" \{.*?\}\n/s,
        &1,
        "\n"
      )
    )
    |> then(
      &Regex.replace(
        ~r/\n\/\* daisyUI theme plugin\..*?(?=\n\/\* Add variants|\n@custom-variant|\z)/s,
        &1,
        "\n"
      )
    )
    |> normalize_blank_lines()
  end

  defp remove_esbuild_config(content) do
    ~r/\n# Configure esbuild.*?(?=\n# Configure tailwind)/s
    |> Regex.replace(content, "\n")
    |> normalize_blank_lines()
  end

  defp remove_tailwind_config(content) do
    ~r/\n# Configure tailwind.*?(?=\n# Configure Elixir)/s
    |> Regex.replace(content, "\n")
    |> normalize_blank_lines()
  end

  defp patch_watchers(content) do
    if String.contains?(content, ~s(npm: ["run", "dev")) do
      content
    else
      Regex.replace(
        ~r/watchers:\s*\[\n\s*esbuild:.*?\n\s*\]/s,
        content,
        """
        watchers: [
            npm: ["run", "dev", cd: Path.expand("../assets", __DIR__)]
          ]\
        """
      )
    end
  end

  defp normalize_topbar_import(content) do
    Regex.replace(
      ~r/^import topbar from ["'](?:\.\.\/vendor\/)?topbar["'];?$/m,
      content,
      ~s(import topbar from "topbar";)
    )
  end

  defp relative_path(from_dir, to_path) do
    from_parts = from_dir |> Path.expand() |> Path.split()
    to_parts = to_path |> Path.expand() |> Path.split()
    {from_parts, to_parts} = trim_common_path(from_parts, to_parts)

    case List.duplicate("..", length(from_parts)) ++ to_parts do
      [] -> "."
      parts -> Path.join(parts)
    end
  end

  defp trim_common_path([part | from_parts], [part | to_parts]) do
    trim_common_path(from_parts, to_parts)
  end

  defp trim_common_path(from_parts, to_parts), do: {from_parts, to_parts}

  defp remove_phoenix_esbuild_comments(content) do
    Regex.replace(
      ~r/\n\/\/ If you have dependencies that try to import CSS, esbuild will generate.*?\n\/\/ To load it, simply add a second `<link>` to your `root\.html\.heex` file\.\n/s,
      content,
      "\n"
    )
  end

  defp remove_default_daisyui_vendor(project_root) do
    project_root
    |> Path.join("assets/vendor/daisyui*.js")
    |> Path.wildcard()
    |> Enum.each(fn path ->
      File.rm!(path)
      Mix.shell().info("Removed #{Path.relative_to_cwd(path)}")
    end)
  end

  defp normalize_blank_lines(content) do
    Regex.replace(~r/\n{3,}/, content, "\n\n")
  end
end
