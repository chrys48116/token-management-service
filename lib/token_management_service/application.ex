defmodule TokenManagementService.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TokenManagementServiceWeb.Telemetry,
      TokenManagementService.Repo,
      {DNSCluster, query: Application.get_env(:token_management_service, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TokenManagementService.PubSub},
      # Start a worker by calling: TokenManagementService.Worker.start_link(arg)
      # {TokenManagementService.Worker, arg},
      # Start to serve requests, typically the last entry
      TokenManagementService.Tokens.Supervisor,
      TokenManagementServiceWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TokenManagementService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TokenManagementServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
