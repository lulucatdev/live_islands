defmodule LiveReact.Installer do
  @moduledoc false

  @doc false
  def dependency_path do
    Mix.Project.deps_paths(depth: 1)
    |> Map.get(:live_react, File.cwd!())
  end

  @doc false
  def install(project_root \\ File.cwd!(), dependency_root \\ dependency_path()) do
    copy_templates(project_root, dependency_root)
    patch_project(project_root)
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
  def patch_project(project_root) do
    patch_file(Path.join([project_root, "assets", "js", "app.js"]), &patch_app_js/1)
    patch_file(Path.join([project_root, "config", "config.exs"]), &patch_base_config/1)
    patch_file(Path.join([project_root, "config", "dev.exs"]), &patch_dev_config/1)
    patch_file(Path.join([project_root, "config", "prod.exs"]), &patch_prod_config/1)
  end

  @doc false
  def patch_app_js(content) do
    content
    |> ensure_import(~s(import components from "../react-components";))
    |> ensure_import(~s(import { getHooks } from "live_react";))
    |> ensure_live_socket_hooks()
  end

  @doc false
  def patch_base_config(content) do
    append_config_once(
      content,
      "config :live_react",
      """

      config :live_react,
        ssr: true,
        enable_props_diff: true
      """
    )
  end

  @doc false
  def patch_dev_config(content) do
    append_config_once(
      content,
      "LiveReact.SSR.ViteJS",
      """

      config :live_react,
        vite_host: "http://localhost:5173",
        ssr_module: LiveReact.SSR.ViteJS
      """
    )
  end

  @doc false
  def patch_prod_config(content) do
    append_config_once(
      content,
      "LiveReact.SSR.NodeJS",
      """

      config :live_react,
        ssr_module: LiveReact.SSR.NodeJS
      """
    )
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
      case Regex.run(~r/^import topbar from ["']topbar["'];?$/m, content) do
        [topbar_import] ->
          String.replace(content, topbar_import, topbar_import <> "\n" <> import_line)

        _ ->
          import_line <> "\n" <> content
      end
    end
  end

  defp ensure_live_socket_hooks(content) do
    cond do
      String.contains?(content, "getHooks(components)") ->
        content

      Regex.match?(~r/hooks:\s*([^,\n]+),/, content) ->
        Regex.replace(~r/hooks:\s*([^,\n]+),/, content, fn _match, hooks ->
          "hooks: {...#{String.trim(hooks)}, ...getHooks(components)},"
        end)

      true ->
        String.replace(
          content,
          ~r/(new LiveSocket\([^,]+,\s*Socket,\s*\{)/,
          "\\1\n  hooks: getHooks(components),"
        )
    end
  end

  defp append_config_once(content, marker, block) do
    if String.contains?(content, marker),
      do: content,
      else: String.trim_trailing(content) <> block <> "\n"
  end
end
