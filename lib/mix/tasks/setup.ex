defmodule Mix.Tasks.LiveReact.Setup do
  @moduledoc """
  Copies files from assets/copy of the live_islands dependency to phoenix project assets folder
  """
  @shortdoc "copy setup files to assets"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    dependency_root = LiveIslands.Installer.dependency_path()
    LiveIslands.Installer.copy_templates(File.cwd!(), dependency_root)
  end
end
