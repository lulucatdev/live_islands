defmodule Mix.Tasks.LiveIslands.VerifyInstall do
  @moduledoc """
  Verifies that a Phoenix project is wired for LiveIslands.

      mix live_islands.verify_install
      mix live_islands.verify_install --full
      mix live_islands.verify_install --full --install

  The default mode checks static integration points. `--full` also runs the
  Vite client build, SSR bundle build, and build artifact checks. Use
  `--skip-ssr` when the project intentionally sets `config :live_islands,
  ssr: false`.
  """

  use Mix.Task

  @shortdoc "verifies LiveIslands integration files, builds, and artifacts"

  @impl Mix.Task
  def run(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args,
        strict: [
          full: :boolean,
          install: :boolean,
          skip_ssr: :boolean
        ]
      )

    if invalid != [] do
      invalid_flags = Enum.map_join(invalid, ", ", fn {flag, _value} -> flag end)
      Mix.raise("Unknown option(s): #{invalid_flags}")
    end

    result =
      if opts[:full] do
        LiveIslands.InstallVerifier.verify_full(File.cwd!(),
          install?: opts[:install],
          skip_ssr?: opts[:skip_ssr]
        )
      else
        LiveIslands.InstallVerifier.verify(File.cwd!())
      end

    case result do
      {:ok, checks} ->
        print_checks(checks)
        Mix.shell().info("\nLiveIslands installation looks complete.")

      {:error, checks} ->
        print_checks(checks)

        Mix.raise("""
        LiveIslands installation is incomplete.

        Fix the missing items above, then run:
          mix live_islands.verify_install --full

        If node modules are not installed yet, run:
          mix live_islands.verify_install --full --install
        """)
    end
  end

  defp print_checks(checks) do
    Enum.each(checks, fn %{name: name, ok?: ok?, detail: detail} ->
      status = if ok?, do: "ok", else: "missing"
      Mix.shell().info("[#{status}] #{name}: #{detail}")
    end)
  end
end
