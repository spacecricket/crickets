defmodule Crickets.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      CricketsWeb.Telemetry,
      # Start the Ecto repository
      Crickets.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Crickets.PubSub},
      # Presense tracker
      CricketsWeb.Presence,
      # Start Finch
      {Finch, name: Crickets.Finch},
      # Start the Endpoint (http/https)
      CricketsWeb.Endpoint
      # Start a worker by calling: Crickets.Worker.start_link(arg)
      # {Crickets.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Crickets.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CricketsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
