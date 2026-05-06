defmodule LiveIslandsExamples.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {NodeJS.Supervisor, [path: LiveIslands.SSR.NodeJS.server_path(), pool_size: 1]},
      LiveIslandsExamplesWeb.Telemetry,
      {DNSCluster,
       query: Application.get_env(:live_islands_examples, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LiveIslandsExamples.PubSub},
      # Start a worker by calling: LiveIslandsExamples.Worker.start_link(arg)
      # {LiveIslandsExamples.Worker, arg},
      # Start to serve requests, typically the last entry
      LiveIslandsExamplesWeb.Endpoint
    ]

    # Set up LiveIslandsExamples.Telemetry
    LiveIslandsExamples.Telemetry.setup()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveIslandsExamples.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LiveIslandsExamplesWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
