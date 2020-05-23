defmodule Hal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      HalWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Hal.PubSub},
      # Start the Endpoint (http/https)
      HalWeb.Endpoint,
      # Start the RS485 sniffer
      {Hal.Rs485, Application.get_env(:hal, :rs485_port)},
      # Start the GenServer which handles state and MQTT pubsub
      {Hal.State,
       %{
         broker: Application.get_env(:hal, :mqtt_broker),
         publish_interval: Application.get_env(:hal, :publish_interval_ms)
       }}
      # Start a worker by calling: Hal.Worker.start_link(arg)
      # {Hal.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Hal.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    HalWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
