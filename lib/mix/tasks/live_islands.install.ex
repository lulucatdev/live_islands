defmodule Mix.Tasks.LiveIslands.Install do
  @moduledoc """
  Installs LiveIslands assets and common Phoenix configuration.
  """

  use Mix.Task

  @shortdoc "installs LiveIslands assets and common Phoenix configuration"

  @impl Mix.Task
  def run(_args) do
    LiveIslands.Installer.install()

    Mix.shell().info("""

    LiveIslands installation files are in place.

    Your Phoenix assets now use Vite + Tailwind CSS through npm, without daisyUI.
    Review the generated React and Vue island roots, then run `npm install --prefix assets`.
    """)
  end
end
