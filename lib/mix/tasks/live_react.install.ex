defmodule Mix.Tasks.LiveReact.Install do
  @moduledoc """
  Installs LiveReact assets and common Phoenix configuration.

  The task copies the Vite, TypeScript, SSR, and React component templates into
  `assets/`, then applies conservative edits to common Phoenix files:

    * `assets/js/app.js` gets LiveReact hooks
    * `config/config.exs` enables SSR and props diffing
    * `config/dev.exs` configures Vite SSR
    * `config/prod.exs` configures NodeJS SSR

  Existing template files are preserved.
  """

  @shortdoc "installs LiveReact assets and common Phoenix configuration"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    LiveIslands.Installer.install()

    Mix.shell().info("""

    LiveReact compatibility installation files are in place through LiveIslands.

    Review the generated assets and ensure `import LiveIslands` is present in
    your web module's `html_helpers/0`. Then run:

        npm install --prefix assets
    """)
  end
end
