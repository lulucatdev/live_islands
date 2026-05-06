defmodule LiveIslands.Installer do
  @moduledoc false

  @doc false
  def dependency_path do
    Mix.Project.deps_paths(depth: 1)
    |> Map.get(:live_islands, File.cwd!())
  end

  @doc false
  def install(project_root \\ File.cwd!(), dependency_root \\ dependency_path()) do
    copy_templates(project_root, dependency_root)
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
end
