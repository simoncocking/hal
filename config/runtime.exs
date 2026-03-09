import Config

if config_env() == :prod do
  config :hal,
    mqtt_broker: System.get_env("MQTT_BROKER", "inverter"),
    rs485_port: System.get_env("RS485_PORT", "ttyAMA0")
end
