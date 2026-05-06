defmodule Mix.Tasks.LiveIslands.Setup do
  @moduledoc """
  Copies LiveIslands template files into the Phoenix assets folder.
  """

  use Mix.Task

  @shortdoc "copy LiveIslands setup files to assets"

  @impl Mix.Task
  def run(_args) do
    dependency_root = LiveIslands.Installer.dependency_path()
    LiveIslands.Installer.copy_templates(File.cwd!(), dependency_root)
  end
end
