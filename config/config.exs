import Config

config :hal,
  mqtt_broker: "localhost",
  rs485_port: "ttyAMA0"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
