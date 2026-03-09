import Config

config :hal,
  mqtt_broker: "inverter.local",
  rs485_port: "ttyAMA0"

config :logger, :console, format: "[$level] $message\n"
