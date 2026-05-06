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

    Review the generated assets and ensure `import LiveIslands` is present in
    your web helpers when you want to use <.react> and <.vue> directly.
    """)
  end
end
