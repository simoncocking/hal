defmodule Hal.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    mqtt_broker = Application.get_env(:hal, :mqtt_broker, "localhost")
    rs485_port = Application.get_env(:hal, :rs485_port, "ttyAMA0")

    children = [
      # MQTT connection via Tortoise
      {Tortoise311.Connection,
       client_id: Hal.MQTT,
       server: {Tortoise311.Transport.Tcp, host: String.to_charlist(mqtt_broker), port: 1883},
       handler: {Tortoise311.Handler.Default, []}},

      # RS485 data acquisition from Sunny Island remote control bus
      {Hal.Rs485, rs485_port}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Hal.Supervisor)
  end
end
