defmodule Mix.Tasks.LiveIslands.Install do
  @moduledoc """
  Copies optional LiveIslands asset templates into a Phoenix project.
  """

  use Mix.Task

  @shortdoc "copies optional LiveIslands asset templates"

  @impl Mix.Task
  def run(_args) do
    LiveIslands.Installer.install()

    Mix.shell().info("""

    LiveIslands scaffold files are in place.

    This task only copies missing template files under assets/.
    It does not patch mix.exs, app.js, layouts, config, Tailwind, or daisyUI.

    Use the LiveIslands install skill or guides/installation.md to wire the
    project intentionally, then run `mix live_islands.verify_install`.
    """)
  end
end
