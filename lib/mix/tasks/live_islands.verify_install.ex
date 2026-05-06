defmodule Mix.Tasks.LiveIslands.VerifyInstall do
  @moduledoc """
  Verifies that a Phoenix project is wired for LiveIslands.
  """

  use Mix.Task

  @shortdoc "verifies LiveIslands integration files and configuration"

  @impl Mix.Task
  def run(_args) do
    case LiveIslands.InstallVerifier.verify(File.cwd!()) do
      {:ok, checks} ->
        print_checks(checks)
        Mix.shell().info("\nLiveIslands installation looks complete.")

      {:error, checks} ->
        print_checks(checks)

        Mix.raise("""
        LiveIslands installation is incomplete.

        Fix the missing items above, then run:
          npm install --prefix assets
          npm run build --prefix assets
          npm run build-server --prefix assets
          mix compile
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
