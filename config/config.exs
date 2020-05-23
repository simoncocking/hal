# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :hal, HalWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "qC7XS3U9sTPhWnUxWN+RAIvpKmxa8LRhrVnspgNAG6a5GYyAbB64GWJ6SKpAuCFd",
  render_errors: [view: HalWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Hal.PubSub,
  live_view: [signing_salt: "W6wT5RRB"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
