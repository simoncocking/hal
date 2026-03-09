import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :hal, HalWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "DR1EqRCtVb+X8ylMpQVv7BhVnRIbhPJtZY7BgtRwvEF5+/xa4IvHksVx1w2im6re",
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# In test we don't send emails.
config :hal, Hal.Mailer, adapter: Swoosh.Adapters.Test

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
