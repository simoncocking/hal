defmodule Hal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the PubSub system
      {Phoenix.PubSub, name: Hal.PubSub},
      # Start a worker by calling: Hal.Worker.start_link(arg)
      # {Hal.Worker, arg}
      {Hal.Rs485, Application.get_env(:hal, :rs485_port)},
      # Start the GenServer which handles state and MQTT pubsub
      {Hal.State, %{broker: Application.get_env(:hal, :mqtt_broker)}}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Hal.Supervisor)
  end
end
