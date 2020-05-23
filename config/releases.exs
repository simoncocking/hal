import Config

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

config :hal,
  mqtt_broker: "inverter.local",
  publish_interval_ms: 1000,
  rs485_port: "ttyAMA0"

config :hal, HalWeb.Endpoint,
  server: true,
  http: [port: 80],
  url: [host: "rs485.local", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: secret_key_base

config :logger, level: :info

config :phoenix, serve_endpoints: true
